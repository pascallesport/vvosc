//
//  OSCInPort.m
//  OSC
//
//  Created by bagheera on 9/20/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "OSCInPort.h"




@implementation OSCInPort


- (NSString *) description	{
	return [NSString stringWithFormat:@"<OSCInPort: %ld>",port];
}
+ (id) createWithPort:(short)p	{
	OSCInPort		*returnMe = [[OSCInPort alloc] initWithPort:p labelled:nil];
	if (returnMe == nil)
		return nil;
	return [returnMe autorelease];
}
+ (id) createWithPort:(short)p labelled:(NSString *)l	{
	OSCInPort		*returnMe = [[OSCInPort alloc] initWithPort:p labelled:l];
	if (returnMe == nil)
		return nil;
	return [returnMe autorelease];
}
- (id) initWithPort:(short)p	{
	return [self initWithPort:p labelled:nil];
}
- (id) initWithPort:(short)p labelled:(NSString *)l	{
	pthread_mutexattr_t		attr;
	
	self = [super init];
	deleted = NO;
	port = p;
	running = NO;
	busy = NO;
	
	pthread_mutexattr_init(&attr);
	pthread_mutexattr_settype(&attr, PTHREAD_MUTEX_NORMAL);
	pthread_mutex_init(&lock, &attr);
	
	threadTimer = nil;
	threadTimerCount = 0;
	
	portLabel = nil;
	if (l != nil)
		portLabel = [l copy];
	
	scratchDict = [[NSMutableDictionary dictionaryWithCapacity:0] retain];
	scratchArray = [[NSMutableArray arrayWithCapacity:0] retain];
	
	delegate = nil;
	
	zeroConfDest = nil;
	
	bound = [self createSocket];
	if (!bound)	{
		[self release];
		return nil;
	}
	
	return self;
}
- (void) dealloc	{
	//NSLog(@"OSCInPort:dealloc:");
	if (!deleted)
		[self prepareToBeDeleted];
	if (scratchDict != nil)
		[scratchDict release];
	scratchDict = nil;
	if (scratchArray != nil)
		[scratchArray release];
	scratchArray = nil;
	if (portLabel != nil)
		[portLabel release];
	portLabel = nil;
	pthread_mutex_destroy(&lock);
	[super dealloc];
}
- (void) prepareToBeDeleted	{
	delegate = nil;
	if (running)
		[self stop];
	close(sock);
	sock = -1;
	
	deleted = YES;
}

- (NSDictionary *) createSnapshot	{
	NSMutableDictionary		*returnMe = [NSMutableDictionary dictionaryWithCapacity:0];
	[returnMe setObject:[NSNumber numberWithInt:port] forKey:@"port"];
	if (portLabel != nil)
		[returnMe setObject:portLabel forKey:@"portLabel"];
	return returnMe;
}

- (BOOL) createSocket	{
	//	create a UDP socket
	sock = socket(PF_INET, SOCK_DGRAM, 0);
	if (sock < 0)
		return NO;
	//	set the socket to non-blocking
	//fcntl(sock, F_SETFL, 0_NONBLOCK);
	//	prep the sockaddr_in struct
	addr.sin_family = AF_INET;
	addr.sin_port = htons(port);
	addr.sin_addr.s_addr = htonl(INADDR_ANY);
	memset(addr.sin_zero, '\0', sizeof(addr.sin_zero));
	//	bind the socket
	if (bind(sock, (struct sockaddr *)&addr, sizeof(addr)) < 0)	{
		NSLog(@"\t\terr: couldn't bind socket for OSC");
		return NO;
	}
	
	return YES;
}
- (void) start	{
	if ((busy) || (running))	{
		NSLog(@"\t\terr: tried to start a busy port");
		return;
	}
	running = YES;
	[NSThread detachNewThreadSelector:@selector(launchOSCLoop:) toTarget:self withObject:nil];
	
	//	if there's a port name, create a NSNetService so devices using bonjour know they can send data to me
	if (portLabel != nil)	{
		NSLog(@"\t\tpublishing zeroConf: %ld, %@ %@",port,CSCopyMachineName(),portLabel);
		if (zeroConfDest != nil)	{
			[zeroConfDest stop];
			[zeroConfDest release];
		}
		zeroConfDest = [[NSNetService alloc]
			initWithDomain:@"local."
			type:@"_osc._udp."
			name:[NSString stringWithFormat:@"%@ %@",CSCopyMachineName(),portLabel]
			port:port];
		[zeroConfDest publish];
	}
	else
		NSLog(@"\t\terr: couldn't make zero conf dest, portLabel was nil");
}
- (void) stop	{
	if ((threadTimer == nil) || (!running))	{
		NSLog(@"\t\terr: tried to stop a port with a nil timer");
		return;
	}
	running = NO;
	busy = YES;
	
	//	stop & release the bonjour service
	if (zeroConfDest != nil)	{
		[zeroConfDest stop];
		[zeroConfDest release];
		zeroConfDest = nil;
	}
	
	while (threadTimer != nil)	{
		//NSLog(@"\t\twaiting for OSC thread to stop...");
		usleep(1000);
	}
}
- (void) launchOSCLoop:(id)o	{
	threadPool = [[NSAutoreleasePool alloc] init];
	
	NSAutoreleasePool	*pool = threadPool;
	NSRunLoop			*runLoop = [NSRunLoop currentRunLoop];
	
	threadTimer = [NSTimer
		scheduledTimerWithTimeInterval:0.015
		target:(id)self
		selector:@selector(OSCThreadProc:)
		userInfo:nil
		repeats:YES];
	
	[runLoop addTimer:threadTimer forMode:NSDefaultRunLoopMode];
	[runLoop run];
	busy = NO;
	threadPool = nil;
	[pool release];
}
- (void) OSCThreadProc:(NSTimer *)t	{
	//NSLog(@"OSCInPort:OSCThreadProc:");
	//	if i'm no longer supposed to be running, kill the thread
	if (!running)	{
		if (threadTimer != nil)	{
			[threadTimer invalidate];
			threadTimer = nil;
		}
		return;
	}
	//	if i'm not bound, return
	if (!bound)
		return;
	
	fd_set				readFileDescriptor;
	int					readyFileCount;
	struct timeval		timeout;
	
	//	set up the file descriptors and timeout struct
	FD_ZERO(&readFileDescriptor);
	FD_SET(sock, &readFileDescriptor);
	timeout.tv_sec = 0;
	timeout.tv_usec = 10000;		//	0.01 secs = 100hz
	
	//	figure out if there are any open file descriptors
	readyFileCount = select(sock+1, &readFileDescriptor, (fd_set *)NULL, (fd_set *)NULL, &timeout);
	if (readyFileCount < 0)	{	//	if there was an error, bail immediately
		NSLog(@"\t\terr: socked got closed unexpectedly");
		[self stop];
		if (threadTimer != nil)	{
			[threadTimer invalidate];
			threadTimer = nil;
		}
	}
	//NSLog(@"\t\tcounted %ld ready files",readyFileCount);
	//	if the socket is one of the file descriptors, i need to get data from it
	while (FD_ISSET(sock, &readFileDescriptor))	{
		//NSLog(@"\t\twhile/packet ping");
		//	if i'm no longer supposed to be running, kill the thread
		if (!running)	{
			if (threadTimer != nil)	{
				[threadTimer invalidate];
				threadTimer = nil;
			}
			return;
		}
		
		struct sockaddr_in		addrFrom;
		socklen_t				addrFromLen;
		int						numBytes;
		BOOL					skipThisPacket = NO;
		
		addrFromLen = sizeof(addrFrom);
		numBytes = recvfrom(sock, buf, 8192, 0, (struct sockaddr *)&addrFrom, &addrFromLen);
		if (numBytes < 1)	{
			NSLog(@"\t\terr on recvfrom: %i",errno);
			skipThisPacket = YES;
		}
		if (numBytes % 4)	{
			NSLog(@"\t\terr: bytes isn't multiple of 4");
			skipThisPacket = YES;
		}
		
		if (!skipThisPacket)	{
			buf[numBytes] = '\0';
			/*
				if i've reached this point, i have a buffer of the appropriate
				length which needs to be parsed.  the buffer doesn't contain
				multiple messages, or multiple root-level bundles
			*/
			
			[self parseRawBuffer:buf ofMaxLength:numBytes];
		}
		
		readyFileCount = select(sock+1, &readFileDescriptor, (fd_set *)NULL, (fd_set *)NULL, &timeout);
	}
	//	if there's stuff in the scratch dict, i have to pass the info on to my delegate
	if ([scratchDict count] > 0)	{
		NSDictionary		*tmpDict = nil;
		NSArray				*tmpArray = nil;
		
		pthread_mutex_lock(&lock);
			tmpDict = [NSDictionary dictionaryWithDictionary:scratchDict];
			[scratchDict removeAllObjects];
			tmpArray = [NSArray arrayWithArray:scratchArray];
			[scratchArray removeAllObjects];
		pthread_mutex_unlock(&lock);
		
		[self handleParsedScratchDict:tmpDict];
		[self handleScratchArray:tmpArray];
	}
	
	//	bump the threadTimercount, drain the autorelease pool periodically
	++threadTimerCount;
	if (threadTimerCount > 1024)	{
		[threadPool drain];
		threadTimerCount = 0;
	}
}
/*
	this method exists so subclasses of OSCInPort can subclass around this for custom behavior
*/
- (void) parseRawBuffer:(unsigned char *)b ofMaxLength:(int)l	{
	[OSCPacket
		parseRawBuffer:b
		ofMaxLength:l
		toInPort:self];
}
/*
	these methods exists so subclasses of me can subclass around this and handle the parsed
	contents of the scratch dict however they like
*/
- (void) handleParsedScratchDict:(NSDictionary *)d	{
	//NSLog(@"OSCInPort:handleParsedScratchDict: ... %@",d);
	if ((delegate != nil) && ([delegate respondsToSelector:@selector(oscMessageReceived:)]))
		[delegate oscMessageReceived:d];
}
- (void) handleScratchArray:(NSArray *)a	{
	//NSLog(@"OSCInPort:handleScratchArray: ... %@",a);
	if ((delegate != nil) && ([delegate respondsToSelector:@selector(receivedOSCVal:forAddress:)]))	{
		NSEnumerator		*it = [a objectEnumerator];
		AddressValPair		*anObj;
		while (anObj = [it nextObject])	{
			[delegate receivedOSCVal:[anObj val] forAddress:[anObj address]];
		}
	}
}
/*
	these methods exist so received messages can be added to my scratch dict and scratch array for output
*/
- (void) addValue:(id)val toAddressPath:(NSString *)p	{
	//NSLog(@"OSCInPort:addValue:toAddressPath: ... %@ : %@",p,val);
	if ((val == nil) || (p == nil))
		return;
	
	NSMutableArray		*addressArray = nil;
	AddressValPair		*pair = nil;
	
	pthread_mutex_lock(&lock);
		//	make an address/val pair, add it to the array
		pair = [AddressValPair createWithAddress:p val:val];
		[scratchArray addObject:pair];
		
		//	find the array of msgs in the scratch dict (coalesced messages)
		addressArray = [scratchDict objectForKey:p];
		if (addressArray == nil)	{
			//	if there's no msg array, make one
			addressArray = [NSMutableArray arrayWithCapacity:0];
			[scratchDict setObject:addressArray forKey:p];
		}
		//	add the val to the msg array
		[addressArray addObject:val];
	pthread_mutex_unlock(&lock);
}

- (short) port	{
	return port;
}
- (void) setPort:(short)n	{
	if (n == port)
		return;
	
	short			oldPort = port;
	
	//	stop & close my socket
	[self stop];
	close(sock);
	sock = -1;
	//	clear out the scratch dict/array
	pthread_mutex_lock(&lock);
		if (scratchDict != nil)
			[scratchDict removeAllObjects];
		if (scratchArray != nil)
			[scratchArray removeAllObjects];
	pthread_mutex_unlock(&lock);
	//	set up with the new port
	bound = NO;
	running = NO;
	busy = NO;
	port = n;
	bound = [self createSocket];
	//	if i'm bound, start- if i'm not bound, something went wrong- use my old port
	if (bound)
		[self start];
	else	{
		//	close the socket
		close(sock);
		sock = -1;
		//	clear out the scratch dict
		pthread_mutex_lock(&lock);
			if (scratchDict != nil)
				[scratchDict removeAllObjects];
			if (scratchArray != nil)
				[scratchArray removeAllObjects];
		pthread_mutex_unlock(&lock);
		//	set up with the old port
		bound = NO;
		running = NO;
		busy = NO;
		port = oldPort;
		bound = [self createSocket];
		if (bound)
			[self start];
	}
}
- (NSString *) portLabel	{
	return portLabel;
}
- (void) setPortLabel:(NSString *)n	{
	if ((n != nil) && (portLabel != nil) && ([n isEqualToString:portLabel]))
		return;
	
	[self stop];
	
	if (portLabel != nil)
		[portLabel release];
	portLabel = nil;
	
	if (n != nil)
		portLabel = [n copy];
	
	[self start];
}
- (NSNetService *) zeroConfDest	{
	return zeroConfDest;
}
- (BOOL) bound	{
	return bound;
}
- (id) delegate	{
	return delegate;
}
- (void) setDelegate:(id)n	{
	delegate = n;
}


@end

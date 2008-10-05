//
//  OSCInPort.m
//  OSC
//
//  Created by bagheera on 9/20/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "OSCInPort.h"




@implementation OSCInPort


+ (id) createWithPort:(short)p	{
	OSCInPort		*returnMe = [[OSCInPort alloc] initWithPort:p];
	if (returnMe == nil)
		return nil;
	return [returnMe autorelease];
}
- (id) initWithPort:(short)p	{
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
	scratchDict = [[NSMutableDictionary dictionaryWithCapacity:0] retain];
	delegate = nil;
	
	bound = [self createSocket];
	
	return self;
}
- (void) dealloc	{
	if (!deleted)
		[self prepareToBeDeleted];
	if (scratchDict != nil)
		[scratchDict release];
	scratchDict = nil;
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
}
- (void) stop	{
	if ((threadTimer == nil) || (!running))	{
		NSLog(@"\t\terr: tried to stop a port with a nil timer");
		return;
	}
	running = NO;
	busy = YES;
	while (threadTimer != nil)	{
		NSLog(@"\t\twaiting for OSC thread to stop...");
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
		numBytes = recvfrom(sock, buf, 2048, 0, (struct sockaddr *)&addrFrom, &addrFromLen);
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
		
		pthread_mutex_lock(&lock);
			tmpDict = [NSDictionary dictionaryWithDictionary:scratchDict];
			[scratchDict removeAllObjects];
		pthread_mutex_unlock(&lock);
		
		//NSLog(@"\t\tpassing info to delegate:");
		//NSLog(@"%@",tmpDict);
		[self handleParsedScratchDict:tmpDict];
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
	this method exists so subclasses of me can subclass around this and handle the parsed
	contents of the scratch dict however they like
*/
- (void) handleParsedScratchDict:(NSDictionary *)d	{
	if (delegate != nil)
		[delegate oscMessageReceived:d];
}
/*
	this method exists so received messages can be added to my scratch dict for output
*/
- (void) addValue:(id)val toAddressPath:(NSString *)p	{
	if ((val == nil) || (p == nil))
		return;
	
	NSMutableArray		*addressArray = nil;
	
	pthread_mutex_lock(&lock);
		addressArray = [scratchDict objectForKey:p];
		if (addressArray == nil)	{
			addressArray = [NSMutableArray arrayWithCapacity:0];
			[scratchDict setObject:addressArray forKey:p];
		}
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
	bound = NO;
	
	//	release the scratch dict (it's alloc'd in the init)
	if (scratchDict != nil)
		[scratchDict release];
	scratchDict = nil;
	//	initwith the new port
	[self initWithPort:n];
	//	if i'm bound, start- if i'm not bound, something went wrong- use my old port
	if (bound)
		[self start];
	else	{
		close(sock);
		sock = -1;
		if (scratchDict != nil)
			[scratchDict release];
		scratchDict = nil;
		
		[self initWithPort:oldPort];
		if (bound)
			[self start];
	}
}
- (BOOL) bound	{
	return bound;
}
- (void) setDelegate:(id)n	{
	delegate = n;
}


@end

//
//  OSCZeroConfManager.m
//  VVOSC
//
//  Created by bagheera on 12/9/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "OSCZeroConfManager.h"
#import "OSCManager.h"




@implementation OSCZeroConfManager


- (id) initWithOSCManager:(id)m	{
	if (m == nil)	{
		[self release];
		return nil;
	}
	pthread_rwlockattr_t		attr;
	
	self = [super init];
	
	pthread_rwlockattr_init(&attr);
	pthread_rwlockattr_setpshared(&attr, PTHREAD_PROCESS_SHARED);
	pthread_rwlock_init(&domainLock, &attr);
	
	domainBrowser = [[NSNetServiceBrowser alloc] init];
	[domainBrowser setDelegate:self];
	[domainBrowser searchForRegistrationDomains];
	
	domainDict = [[NSMutableDictionary dictionaryWithCapacity:0] retain];
	
	oscManager = m;
	
	return self;
}
- (void) dealloc	{
	oscManager = nil;
	pthread_rwlock_destroy(&domainLock);
	if (domainBrowser != nil)	{
		[domainBrowser stop];
		[domainBrowser release];
		domainBrowser = nil;
	}
	if (domainDict != nil)	{
		[domainDict release];
		domainDict = nil;
	}
	[super dealloc];
}




//	called when an osc service disappears
//	it finds an output matching the service being removed it will release the out port
- (void) serviceRemoved:(NSNetService *)s	{
	//NSLog(@"OSCZeroConfManager:serviceRemoved: ... %@",[s name]);
	OSCOutPort		*foundPort = nil;
	//	try to find an out port in the manager with the same name
	foundPort = [oscManager findOutputWithLabel:[s name]];
	if (foundPort != nil)	{
		//	if i found the out port, delete it...make sure the list of sources gets updated
		[oscManager removeOutput:foundPort];
	}
}
//	called when an osc service (an osc destination) appears
//	it either updates an existing output port or it makes a new output port for the service
- (void) serviceResolved:(NSNetService *)s	{
	//NSLog(@"OSCZeroConfManager:serviceResolved:");
	id					matchingPort = nil;
	NSArray				*addressArray = [s addresses];
	NSEnumerator		*it = [addressArray objectEnumerator];
	NSData				*data = nil;
	struct sockaddr_in	*sock = (struct sockaddr_in *)[data bytes];
	char				*charPtr = nil;
	NSString			*ipString;
	short				port;
	
	//	find the ip address & port of the resolved service
	while ((charPtr == nil) && (data = [it nextObject]))	{
		sock = (struct sockaddr_in *)[data bytes];
		//	only continue if this is an IPv4 address (IPv6s resolve to 0.0.0.0)
		if (sock->sin_family == AF_INET)	{
			charPtr = inet_ntoa(sock->sin_addr);
		}
	}
	ipString = [NSString stringWithCString:charPtr encoding:NSASCIIStringEncoding];
	port = ntohs(sock->sin_port);
	//NSLog(@"\t\t%@",[s name]);
	//NSLog(@"\t\t%@:%ld",ipString,port);
	
	
	//	assemble an array with strings of the ip addresses this machine responds to
	NSArray				*bigIPAddressArray = [[NSHost currentHost] addresses];
	NSCharacterSet		*charSet;
	NSRange				charSetRange;
	NSEnumerator		*addressIt;
	NSString			*addressPtr;
	NSMutableArray		*IPAddressArray = [NSMutableArray arrayWithCapacity:0];
	charSet = [NSCharacterSet characterSetWithCharactersInString:@"abcdefABCDEF:%"];
	//	run through the array of addresses
	addressIt = [bigIPAddressArray objectEnumerator];
	while (addressPtr = [addressIt nextObject])	{
		//	if the address has any alpha-numeric characters, don't add it to the list
		charSetRange = [addressPtr rangeOfCharacterFromSet:charSet];
		//NSLog(@"%@, %d %d",addressPtr,charSetRange.location,charSetRange.length);
		if ((charSetRange.length==0) && (charSetRange.location==NSNotFound))	{
			//	make sure i'm not adding 127.0.0.1!
			if (![addressPtr isEqualToString:@"127.0.0.1"])
				[IPAddressArray addObject:addressPtr];
		}
	}
	//	if the services resolves to an ip address associated with this machine, just bail
	if ([IPAddressArray containsObject:ipString])	{
		return;
	}
	
	
	//	if i'm here, the services resolved to an IP address outside this machine
	//	try to find an out port in the osc manager with a matching name
	matchingPort = [oscManager findOutputWithLabel:[s name]];
	//	if i found a matching out port, update its ip address and port data, then return
	if (matchingPort != nil)	{
		[matchingPort
			setAddressString:ipString
			andPort:ntohs(sock->sin_port)];
		return;
	}
	
	
	//	if i'm here, i couldn't find an out port with the same name.
	//	try to find an out port with the same ip/port data
	matchingPort = [oscManager findOutputWithAddress:ipString andPort:port];
	//	if i found a matching out port, update its name and return
	if (matchingPort != nil)	{
		[matchingPort setPortLabel:[s name]];
		return;
	}
	
	//	if i'm here, i couldn't find an out port with the same address/port
	//	make a new out port with the relevant data
	[oscManager createNewOutputToAddress:ipString atPort:port withLabel:[s name]];
}




//	NSNetServiceBrowser delegate methods
- (void)netServiceBrowser:(NSNetServiceBrowser *)n didFindDomain:(NSString *)d moreComing:(BOOL)m	{
	//NSLog(@"OSCZeroConfManager:netServiceBrowser:didFindDomain:moreComing: ... %@, %ld",d,m);
	OSCZeroConfDomain	*newDomain = nil;
	
	newDomain = [OSCZeroConfDomain createWithDomain:d andDomainManager:self];
	if (newDomain != nil)	{
		pthread_rwlock_wrlock(&domainLock);
			[domainDict setObject:newDomain forKey:d];
		pthread_rwlock_unlock(&domainLock);
	}
}
- (void)netServiceBrowser:(NSNetServiceBrowser *)n didNotSearch:(NSDictionary *)err	{
	//NSLog(@"OSCZeroConfManager:netServiceBrowser:didNotSearch: ... %@",err);
	NSLog(@"\t\terr, oscbm didn't search: %@",err);
}


@end

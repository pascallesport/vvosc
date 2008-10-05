//
//  OSCOutPort.m
//  OSC
//
//  Created by bagheera on 9/20/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "OSCOutPort.h"




@implementation OSCOutPort


+ (id) createWithAddress:(NSString *)a andPort:(short)p	{
	OSCOutPort		*returnMe = [[OSCOutPort alloc] initWithAddress:a andPort:p];
	if (returnMe == nil)
		return nil;
	return [returnMe autorelease];
}
- (id) initWithAddress:(NSString *)a andPort:(short)p	{
	if ((a == nil) || (p < 1024))	{
		[self release];
		return nil;
	}
	
	self = [super init];
	
	deleted = NO;
	sock = -1;
	port = p;
	addressString = [a retain];
	
	//	if i can't make a socket, return nil
	if (![self createSocket])	{
		[self release];
		return nil;
	}
	
	return self;
}
- (void) dealloc	{
	NSLog(@"OSCOutPort:dealloc:");
	if (!deleted)
		[self prepareToBeDeleted];
	if (addressString != nil)
		[addressString release];
	addressString = nil;
	[super dealloc];
}
- (void) prepareToBeDeleted	{
	deleted = YES;
}

- (BOOL) createSocket	{
	sock = socket(PF_INET, SOCK_DGRAM, IPPROTO_UDP);
	if (sock < 0)	{
		NSLog(@"\t\terr: OSCOutPort couldn't create the socket");
		return NO;
	}
	addr.sin_family = AF_INET;
	addr.sin_addr.s_addr = inet_addr([addressString cStringUsingEncoding:NSASCIIStringEncoding]);
	memset(addr.sin_zero, '\0', sizeof(addr.sin_zero));
	addr.sin_port = htons(port);
	
	return YES;
}

- (void) sendThisPacket:(OSCPacket *)p	{
	//NSLog(@"OSCOutPort:sendThisPacket:");
	if ((deleted) || (sock == -1) || (p == nil))
		return;
	//	make sure the packet doesn't get released if its pool gets drained while i'm sending it
	[p retain];
	
	int				numBytesSent = -1;
	int				bufferSize = [p bufferLength];
	unsigned char	*buff = [p payload];
	
	if (buff == NULL)	{
		NSLog(@"\t\terr: packet's buffer was null");
		return;
	}
	//	send the packet's data to the destination
	numBytesSent = sendto(sock, buff, bufferSize, 0, (const struct sockaddr *)&addr, sizeof(addr));
	//	make sure the packet can be freed...
	[p release];
}

- (void) setAddressString:(NSString *)n	{
	//NSLog(@"OSCOutPort:setAddressString: ... %@",n);
	if ((n==nil) || ([addressString isEqualToString:n]))
		return;
	NSRange		bogusCharRange = [n rangeOfCharacterFromSet:[NSCharacterSet letterCharacterSet]];
	if (bogusCharRange.location != NSNotFound)
		return;
	
	sock = -1;
	if (addressString != nil)
		[addressString release];
	addressString = [n retain];
	[self createSocket];
}
- (void) setPort:(short)p	{
	if ((p < 1024) || (p == port))
		return;
	sock = -1;
	port = p;
	[self createSocket];
}
- (void) setAddressString:(NSString *)n andPort:(short)p	{
	//	if the passed address is nil or the port is < 1024, return immediately
	if ((n == nil) || (p < 1024))
		return;
	//	if the new address AND port are the same as the current address/port, return immediately
	if (([n isEqualToString:addressString]) && (p == port))
		return;
	
	sock = -1;
	if (addressString != nil)
		[addressString release];
	addressString = [n retain];
	port = p;
	[self createSocket];
}

- (short) port	{
	return port;
}
- (NSString *) addressString	{
	return addressString;
}


@end

//
//  OSCOutPort.h
//  OSC
//
//  Created by bagheera on 9/20/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#include <arpa/inet.h>

#import "OSCPacket.h"
#import "OSCBundle.h"
#import "OSCMessage.h"




@interface OSCOutPort : NSObject {
	BOOL					deleted;
	int						sock;
	struct sockaddr_in		addr;
	short					port;
	NSString				*addressString;
}

+ (id) createWithAddress:(NSString *)a andPort:(short)p;
- (id) initWithAddress:(NSString *)a andPort:(short)p;
- (void) prepareToBeDeleted;

- (BOOL) createSocket;

- (void) sendThisBundle:(OSCBundle *)b;
- (void) sendThisMessage:(OSCMessage *)m;
- (void) sendThisPacket:(OSCPacket *)p;

- (void) setAddressString:(NSString *)n;
- (void) setPort:(short)p;
- (void) setAddressString:(NSString *)n andPort:(short)p;

- (short) port;
- (NSString *) addressString;

@end

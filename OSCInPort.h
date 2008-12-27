//
//  OSCInPort.h
//  OSC
//
//  Created by bagheera on 9/20/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#if IPHONE
#import <UIKit/UIKit.h>
#else
#import <Cocoa/Cocoa.h>
#endif


//#import <sys/types.h>
//#import <sys/socket.h>
#import <netinet/in.h>

#import <pthread.h>
#import "AddressValPair.h"
#import "OSCPacket.h"
#import "OSCBundle.h"
#import "OSCMessage.h"


@protocol OSCInPortDelegateProtocol
- (void) oscMessageReceived:(NSDictionary *)d;
- (void) receivedOSCVal:(id)v forAddress:(NSString *)a;
@end

@protocol OSCDelegateProtocol
- (void) oscMessageReceived:(NSDictionary *)d;
- (void) receivedOSCVal:(id)v forAddress:(NSString *)a;
@end

///	This class manages everything needed to receive OSC data on a given port
/*!
OSCInPorts are created by the OSCManager- you should never have to explicitly handle their creation or destruction.  each OSCInPort is running in its own separate thread- so make sure anything called as a result of received OSC input is thread-safe!

the documentation here only covers the basics, the header file for this class is small and heavily commented if you want to know more because you're heavily customizing OSCInPort.
*/
@interface OSCInPort : NSObject {
	BOOL					deleted;	//	whether or not i'm deleted- ensures that socket gets closed
	BOOL					bound;		//	whether or not the socket is bound
	int						sock;		//	socket file descriptor.  remember, everything in unix is files!
	struct sockaddr_in		addr;		//	struct that describes *my* address (this is an in port)
	unsigned short			port;		//	the port number i'm receiving from
	BOOL					running;	//	whether or not i should keep running
	BOOL					busy;
	unsigned char			buf[8192];	//	the socket gets data and dumps it here immediately
	
	pthread_mutex_t			lock;
	NSTimer					*threadTimer;
	int						threadTimerCount;
	NSAutoreleasePool		*threadPool;
	
	NSString				*portLabel;		//!<the "name" of the port (added to distinguish multiple osc input ports for bonjour)
	NSNetService			*zeroConfDest;	//	bonjour service for publishing this input's address...only active if there's a portLabel!
	
	NSMutableDictionary		*scratchDict;	//	key of dict is address port; object at key is a mut. array.  coalesced messaging.
	NSMutableArray			*scratchArray;	//	array of AddressValPair objects.  used for serial messaging.
	id						delegate;	//!<my delegate gets notified of incoming messages
}

///	Creates and returns an auto-released OSCInPort for the given port (or nil if the port's busy)
+ (id) createWithPort:(unsigned short)p;
///	Creates and returns an auto-released OSCInPort for the given port and label (or nil if the port's busy)
+ (id) createWithPort:(unsigned short)p labelled:(NSString *)n;
- (id) initWithPort:(unsigned short)p;
- (id) initWithPort:(unsigned short)p labelled:(NSString *)n;

- (void) prepareToBeDeleted;

///	returns an auto-released NSDictionary which describes this port (useful for restoring the state of the port later)
- (NSDictionary *) createSnapshot;

- (BOOL) createSocket;
- (void) start;
- (void) stop;
- (void) launchOSCLoop:(id)o;
- (void) OSCThreadProc:(NSTimer *)t;
- (void) parseRawBuffer:(unsigned char *)b ofMaxLength:(int)l;

///	called internally by this OSCInPort, passed a dict with the coalesced osc updates
- (void) handleParsedScratchDict:(NSDictionary *)d;
///	called internally by this OSCInPort, passed an array of AddressValPair objects corresponding to the serially received data
- (void) handleScratchArray:(NSArray *)a;

- (void) addValue:(id)val toAddressPath:(NSString *)p;

- (unsigned short) port;
- (void) setPort:(unsigned short)n;
- (NSString *) portLabel;
- (void) setPortLabel:(NSString *)n;
- (NSNetService *) zeroConfDest;
- (BOOL) bound;

///	returns the delegate (default is the OSCManager which created me).
- (id) delegate;
///	sets the delegate- the delegate is NOT retained!
- (void) setDelegate:(id)n;

@end

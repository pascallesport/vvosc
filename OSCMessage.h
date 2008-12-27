//
//  OSCMessage.h
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

#import <pthread.h>



///	Describes a series of types/values and the address path they are to be sent to
/*!
According to the OSC spec, a message consists of an address path (where the message should be sent) and zero or more arguments.  An OSCMessage must be created with an address path- once the OSCMessage exists, you may add as many arguments to it as you'd like.
*/
@interface OSCMessage : NSObject {
	NSString			*address;
	NSMutableArray		*typeArray;
	NSMutableArray		*argArray;
	pthread_rwlock_t	lock;
}

+ (void) parseRawBuffer:(unsigned char *)b ofMaxLength:(int)l toInPort:(id)p;
///	Creates & returns an auto-released instance of OSCMessage which will be sent to the passed path
+ (id) createMessageToAddress:(NSString *)a;
- (id) initWithAddress:(NSString *)a;

///	Add the passed int to the message
- (void) addInt:(int)n;
///	Add the passed float to the message
- (void) addFloat:(float)n;
#if IPHONE
///	Add the passed color to the message
- (void) addColor:(UIColor *)c;
#else
///	Add the passed color to the message
- (void) addColor:(NSColor *)c;
#endif
///	Add the passed bool to the message
- (void) addBOOL:(BOOL)n;
///	Add the passed string to the message
- (void) addString:(NSString *)n;

- (int) bufferLength;
- (void) writeToBuffer:(unsigned char *)b;

@end

//
//  OSCMessage.h
//  OSC
//
//  Created by bagheera on 9/20/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <pthread.h>



@interface OSCMessage : NSObject {
	NSString			*address;
	NSMutableArray		*typeArray;
	NSMutableArray		*argArray;
	pthread_rwlock_t	lock;
}

+ (void) parseRawBuffer:(unsigned char *)b ofMaxLength:(int)l toInPort:(id)p;
+ (id) createMessageToAddress:(NSString *)a;
- (id) initWithAddress:(NSString *)a;

- (void) addInt:(int)n;
- (void) addFloat:(float)n;
- (void) addColor:(NSColor *)c;
- (void) addBOOL:(BOOL)n;
- (void) addString:(NSString *)n;

- (int) bufferLength;
- (void) writeToBuffer:(unsigned char *)b;

@end

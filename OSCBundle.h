//
//  OSCBundle.h
//  OSC
//
//  Created by bagheera on 9/20/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "OSCMessage.h"




@interface OSCBundle : NSObject {
	NSMutableArray		*elementArray;	//	array of messages or bundles
}

+ (void) parseRawBuffer:(unsigned char *)b ofMaxLength:(int)l toInPort:(id)p;

+ (id) create;

- (void) addElement:(id)n;

- (int) bufferLength;
- (void) writeToBuffer:(unsigned char *)b;

@end

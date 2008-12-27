//
//  AddressValPair.h
//  VVOSC
//
//  Created by bagheera on 12/11/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#if IPHONE
#import <UIKit/UIKit.h>
#else
#import <Cocoa/Cocoa.h>
#endif


///	Object with an address (NSString) and value (id).  Created by OSCInPort as OSC data is received
@interface AddressValPair : NSObject {
	NSString		*address;
	id				val;
}

///	Creates & returns an auto-released instance with the given address and value (or nil)
+ (id) createWithAddress:(NSString *)a val:(id)v;
- (id) initWithAddress:(NSString *)a val:(id)v;

///	Returns the address
- (NSString *) address;
///	Returns the val
- (id) val;

@end

//
//  MyOSCManager.m
//  VVOSC
//
//  Created by bagheera on 10/3/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "MyOSCManager.h"


@implementation MyOSCManager


- (id) inPortClass	{
	//NSLog(@"MyOSCManager:inPortClass:");
	return [OSCInPortRetainsRaw class];
}

@end

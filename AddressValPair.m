//
//  AddressValPair.m
//  VVOSC
//
//  Created by bagheera on 12/11/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "AddressValPair.h"




@implementation AddressValPair


- (NSString *) description	{
	return [NSString stringWithFormat:@"<AddressValPair- %@ : %@",address,val];
}
+ (id) createWithAddress:(NSString *)a val:(id)v	{
	AddressValPair		*returnMe = [[AddressValPair alloc] initWithAddress:a val:v];
	if (returnMe == nil)
		return nil;
	return [returnMe autorelease];
}
- (id) initWithAddress:(NSString *)a val:(id)v	{
	if ((a==nil) || (v==nil))
		return nil;
	self = [super init];
	address = [a retain];
	val = [v retain];
	return self;
}
- (void) dealloc	{
	[address release];
	address = nil;
	[val release];
	val = nil;
	[super dealloc];
}

- (NSString *) address	{
	return address;
}
- (id) val	{
	return val;
}


@end

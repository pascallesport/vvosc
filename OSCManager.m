//
//  OSCManager.m
//  OSC
//
//  Created by bagheera on 9/20/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "OSCManager.h"




@implementation OSCManager


- (id) init	{
	pthread_rwlockattr_t		attr;
	
	self = [super init];
	
	inPortArray = [[NSMutableArray arrayWithCapacity:0] retain];
	outPortArray = [[NSMutableArray arrayWithCapacity:0] retain];
	
	pthread_rwlockattr_init(&attr);
	pthread_rwlockattr_setpshared(&attr, PTHREAD_PROCESS_SHARED);
	pthread_rwlock_init(&inPortLock, &attr);
	pthread_rwlock_init(&outPortLock, &attr);
	
	return self;
}

- (void) dealloc	{
	pthread_rwlock_destroy(&inPortLock);
	pthread_rwlock_destroy(&outPortLock);
	if (inPortArray != nil)
		[inPortArray release];
	inPortArray = nil;
	if (outPortArray != nil)
		[outPortArray release];
	outPortArray = nil;
	[super dealloc];
}

- (OSCInPort *) createNewInputForPort:(int)p	{
	OSCInPort			*returnMe = nil;
	NSEnumerator		*it;
	OSCInPort			*portPtr;
	BOOL				foundConflict = NO;
	
	pthread_rwlock_wrlock(&inPortLock);
		it = [inPortArray objectEnumerator];
		while ((portPtr = [it nextObject]) && (!foundConflict))	{
			if ([portPtr port] == p)
				foundConflict = YES;
		}
		
		if (!foundConflict)	{
			returnMe = [[[[self inPortClass] alloc] initWithPort:p] autorelease];
			if (returnMe != nil)	{
				[returnMe start];
				[inPortArray addObject:returnMe];
			}
		}
	pthread_rwlock_unlock(&inPortLock);
	
	return returnMe;
}

- (OSCOutPort *) createNewOutputToAddress:(NSString *)a atPort:(int)p	{
	if ((a == nil) || (p < 1024))
		return nil;
	
	OSCOutPort			*returnMe = nil;
	NSEnumerator		*it;
	OSCOutPort			*portPtr;
	BOOL				foundConflict = NO;
	
	pthread_rwlock_wrlock(&outPortLock);
	
		it = [outPortArray objectEnumerator];
		while ((portPtr = [it nextObject]) && (!foundConflict))	{
			if (([[portPtr addressString] isEqualToString:a]) && ([portPtr port] == p))
				foundConflict = YES;
		}
		if (!foundConflict)	{
			returnMe = [[[[self outPortClass] alloc] initWithAddress:a andPort:p] autorelease];
			if (returnMe != nil)
				[outPortArray addObject:returnMe];
		}
	
	pthread_rwlock_unlock(&outPortLock);
	
	return returnMe;
}

/*
	these methods exist to make it easier to sub-class the osc manager and
	use your own custom subclasses of OSCInPort/OSCOutPort
*/
- (id) inPortClass	{
	return [OSCInPort class];
}
- (id) outPortClass	{
	return [OSCOutPort class];
}


@end

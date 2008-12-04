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
	delegate = nil;
	
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
	delegate = nil;
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
				[returnMe setDelegate:self];
				[returnMe start];
				[inPortArray addObject:returnMe];
			}
		}
	pthread_rwlock_unlock(&inPortLock);
	
	return returnMe;
}

- (OSCInPort *) createNewInput	{
	OSCInPort		*portPtr = nil;
	int				portIndex = 1234;
	
	while (portPtr == nil)	{
		portPtr = [self createNewInputForPort:portIndex];
		++portIndex;
	}
	
	return portPtr;
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

- (OSCOutPort *) createNewOutput	{
	OSCOutPort		*portPtr = nil;
	int				portIndex = 1234;
	
	while (portPtr == nil)	{
		portPtr = [self createNewOutputToAddress:@"127.0.0.1" atPort:portIndex];
		++portIndex;
	}
	
	return portPtr;
}

- (void) deleteAllInputs	{
	pthread_rwlock_wrlock(&inPortLock);
	
		[inPortArray makeObjectsPerformSelector:@selector(prepareToBeDeleted)];
		[inPortArray removeAllObjects];
	
	pthread_rwlock_unlock(&inPortLock);
}
- (void) deleteAllOutputs	{
	pthread_rwlock_wrlock(&outPortLock);
	
		[outPortArray makeObjectsPerformSelector:@selector(prepareToBeDeleted)];
		[outPortArray removeAllObjects];
	
	pthread_rwlock_unlock(&outPortLock);
}

/*
	important: this method will be called from any of a number of threads- each port is in its own thread!
	
	typically, the manager is the input port's delegate- input ports tell delegates
	when they receive data.  by default, the manager is the input port's delegate- so
	this method will be called by default if your input port doesn't have another delegate.
	as such, this method tells the manager's delegate about any received osc messages.
*/
- (void) oscMessageReceived:(NSDictionary *)d	{
	if ((delegate != nil) && ([delegate respondsToSelector:@selector(oscMessageReceived:)]))
		[delegate oscMessageReceived:d];
}

- (id) delegate	{
	return delegate;
}
- (void) setDelegate:(id)n	{
	delegate = n;
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

- (NSMutableArray *) inPortArray	{
	return inPortArray;
}
- (NSMutableArray *) outPortArray	{
	return outPortArray;
}


@end

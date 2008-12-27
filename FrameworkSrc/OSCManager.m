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
	
	zeroConfManager = [[OSCZeroConfManager alloc] initWithOSCManager:self];
	
	return self;
}

- (void) dealloc	{
	if (zeroConfManager != nil)	{
		[zeroConfManager release];
		zeroConfManager = nil;
	}
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
/*===================================================================================*/
#pragma mark --------------------- creating input ports
/*------------------------------------*/
- (OSCInPort *) createNewInputFromSnapshot:(NSDictionary *)s	{
	if (s == nil)
		return nil;
	OSCInPort		*returnMe = nil;
	int				port = 1234;
	NSNumber		*numPtr = [s objectForKey:@"port"];
	NSString		*portLabel = [s objectForKey:@"portLabel"];
	if (portLabel == nil)
		portLabel = [self getUniqueInputLabel];
	if (numPtr != nil)
		port = [numPtr intValue];
	returnMe = [self createNewInputForPort:port withLabel:portLabel];
	return returnMe;
}
- (OSCInPort *) createNewInputForPort:(int)p withLabel:(NSString *)l	{
	//NSLog(@"OSCManager:createNewInputForPort:withLabel: ... %ld, %@",p,l);
	OSCInPort			*returnMe = nil;
	NSEnumerator		*it;
	OSCInPort			*portPtr;
	BOOL				foundPortConflict = NO;
	BOOL				foundNameConflict = NO;
	
	pthread_rwlock_wrlock(&inPortLock);
		//	check for port or name conflicts
		it = [inPortArray objectEnumerator];
		while ((portPtr = [it nextObject]) && (!foundPortConflict) && (!foundNameConflict))	{
			if ([portPtr port] == p)
				foundPortConflict = YES;
			if (([portPtr portLabel]!=nil) && ([[portPtr portLabel] isEqualToString:l]))
				foundNameConflict = YES;
		}
		//	if there weren't any conflicts, make an instance set it up and add it to the array
		if ((!foundPortConflict) && (!foundNameConflict))	{
			Class			inPortClass = [self inPortClass];
			
			returnMe = [[inPortClass alloc] initWithPort:p labelled:l];
			
			if (returnMe != nil)	{
				[returnMe setDelegate:self];
				[returnMe start];
				[inPortArray addObject:returnMe];
				[returnMe autorelease];
			}
		}
	pthread_rwlock_unlock(&inPortLock);
	
	return returnMe;
}
- (OSCInPort *) createNewInputForPort:(int)p	{
	OSCInPort			*returnMe = nil;
	NSString			*uniqueLabel = [self getUniqueInputLabel];
	returnMe = [self createNewInputForPort:p withLabel:uniqueLabel];
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
/*===================================================================================*/
#pragma mark --------------------- creating output ports
/*------------------------------------*/
- (OSCOutPort *) createNewOutputFromSnapshot:(NSDictionary *)s	{
	if (s == nil)
		return nil;
	OSCOutPort		*returnMe = nil;
	NSNumber		*numPtr = nil;
	int				port;
	NSString		*addressPtr = nil;
	NSString		*portLabel = nil;
	
	//	find the address- if it's nil, return nil and bail on creation
	addressPtr = [s objectForKey:@"address"];
	if (addressPtr == nil)
		return nil;
	//	find the port- if it's nil, return nil and bail on creation
	numPtr = [s objectForKey:@"port"];
	if (numPtr == nil)
		return nil;
	port = [numPtr intValue];
	//	find the port label- if it's nil, get a new unique port label
	portLabel = [s objectForKey:@"portLabel"];
	if (portLabel == nil)
		portLabel = [self getUniqueOutputLabel];
	
	//	make the output based on the data
	returnMe = [self createNewOutputToAddress:addressPtr atPort:port withLabel:portLabel];
	
	return returnMe;
}
- (OSCOutPort *) createNewOutputToAddress:(NSString *)a atPort:(int)p withLabel:(NSString *)l	{
	//NSLog(@"OSCManager:createNewOutputToAddress:atPort:withLabel: ... %@:%ld, %@",a,p,l);
	if ((a == nil) || (p < 1024) || (l == nil))
		return nil;
	
	OSCOutPort			*returnMe = nil;
	NSEnumerator		*it;
	OSCOutPort			*portPtr;
	BOOL				foundNameConflict = NO;
	
	pthread_rwlock_wrlock(&outPortLock);
		//	check for name conflicts
		it = [outPortArray objectEnumerator];
		while ((portPtr = [it nextObject]) && (!foundNameConflict))	{
			if (([portPtr portLabel]!=nil) && ([[portPtr portLabel] isEqualToString:l]))
				foundNameConflict = YES;
		}
		//	if there weren't any name conflicts, make an instance and add it to the array
		if (!foundNameConflict)	{
			Class			outPortClass = [self outPortClass];
			
			returnMe = [[outPortClass alloc] initWithAddress:a andPort:p labelled:l];
			
			if (returnMe != nil)	{
				[outPortArray addObject:returnMe];
				[returnMe autorelease];
			}
		}
	pthread_rwlock_unlock(&outPortLock);
	
	return returnMe;
}
- (OSCOutPort *) createNewOutputToAddress:(NSString *)a atPort:(int)p	{
	OSCOutPort			*returnMe = nil;
	NSString			*uniqueLabel = [self getUniqueOutputLabel];
	returnMe = [self createNewOutputToAddress:a atPort:p withLabel:uniqueLabel];
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

/*===================================================================================*/
#pragma mark --------------------- main osc callback
/*------------------------------------*/
/*!
	this method is passed a dict; the keys of the dict are the address paths, and the object at each key is an array which contains the values passed to the address path.  this is referred to as "coalesced" updates because the values are organized by address path.
	
	important: this method will be called from any of a number of threads- each port is running in its own thread!
	
	typically, the manager is the input port's delegate- input ports tell delegates when they receive data.  by default, the manager is the input port's delegate- so this method will be called by default if your input port doesn't have another delegate.  as such, this method tells the manager's delegate about any received osc messages.
*/
- (void) oscMessageReceived:(NSDictionary *)d	{
	//NSLog(@"OSCManager:oscMessageReceived: ... %@",d);
	if ((delegate != nil) && ([delegate respondsToSelector:@selector(oscMessageReceived:)]))
		[delegate oscMessageReceived:d];
}
/*!
	the address (a) is the address path, (v) is the value passed to it.  this method is called immediately, as the incoming OSC data is received- no attempt is made to coalesce the updates and sort them by address.
	
	important: this method will be called from any of a number of threads- each port is running in its own thread!
	
	typically, the manager is the input port's delegate- input ports tell delegates when they receive data.  by default, the manager is the input port's delegate- so this method will be called by default if your input port doesn't have another delegate.  as such, this method tells the manager's delegate about any received osc messages.
*/
- (void) receivedOSCVal:(id)v forAddress:(NSString *)a	{
	//NSLog(@"OSCManager:receivedOSCVal:forAddress: ... %@:%@",a,v);
	if ((delegate != nil) && ([delegate respondsToSelector:@selector(receivedOSCVal:forAddress:)]))
		[delegate receivedOSCVal:v forAddress:a];
}
/*===================================================================================*/
#pragma mark --------------------- working with ports
/*------------------------------------*/
- (NSString *) getUniqueInputLabel	{
	NSString		*tmpString = nil;
	NSEnumerator	*it;
	BOOL			found = NO;
	BOOL			alreadyInUse = NO;
	OSCInPort		*portPtr = nil;
	int				index = 1;
	
	pthread_rwlock_rdlock(&inPortLock);
		while (!found)	{
			tmpString = [NSString stringWithFormat:@"%@ %ld",[self inPortLabelBase],index];
			
			alreadyInUse = NO;
			it = [inPortArray objectEnumerator];
			while ((!alreadyInUse) && (portPtr = [it nextObject]))	{
				if ([[portPtr portLabel] isEqualToString:tmpString])	{
					alreadyInUse = YES;
				}
			}
			
			if ((tmpString != nil) && (!alreadyInUse))	{
				found = YES;
			}
			
			++index;
		}
	pthread_rwlock_unlock(&inPortLock);
	
	return tmpString;
}
- (NSString *) getUniqueOutputLabel	{
	NSString		*tmpString = nil;
	NSEnumerator	*it;
	BOOL			found = NO;
	BOOL			alreadyInUse = NO;
	OSCOutPort		*portPtr = nil;
	int				index = 1;
	
	pthread_rwlock_rdlock(&outPortLock);
	
		while (!found)	{
			tmpString = [NSString stringWithFormat:@"OSC Out Port %ld",index];
			
			alreadyInUse = NO;
			it = [outPortArray objectEnumerator];
			while ((!alreadyInUse) && (portPtr = [it nextObject]))	{
				if ([[portPtr portLabel] isEqualToString:tmpString])	{
					alreadyInUse = YES;
				}
			}
			
			if ((tmpString!=nil) && (!alreadyInUse))	{
				found = YES;
			}
			
			++index;
		}
	
	pthread_rwlock_unlock(&outPortLock);
	
	return tmpString;
}
- (OSCInPort *) findInputWithLabel:(NSString *)n	{
	if (n == nil)
		return nil;
	
	OSCInPort		*foundPort = nil;
	NSEnumerator	*it;
	OSCInPort		*portPtr = nil;
	
	pthread_rwlock_rdlock(&inPortLock);
		it = [inPortArray objectEnumerator];
		while ((portPtr = [it nextObject]) && (foundPort == nil))	{
			if ([[portPtr portLabel] isEqualToString:n])	{
				foundPort = portPtr;
			}
		}
	pthread_rwlock_unlock(&inPortLock);
	
	return foundPort;
}
- (OSCOutPort *) findOutputWithLabel:(NSString *)n	{
	if (n == nil)	{
		return nil;
	}
	
	OSCOutPort		*foundPort = nil;
	NSEnumerator		*it;
	OSCOutPort		*portPtr = nil;
	
	pthread_rwlock_rdlock(&outPortLock);
		it = [outPortArray objectEnumerator];
		while ((portPtr = [it nextObject]) && (foundPort == nil))	{
			if ([[portPtr portLabel] isEqualToString:n])	{
				foundPort = portPtr;
			}
		}
	pthread_rwlock_unlock(&outPortLock);
	
	return foundPort;
}


- (OSCOutPort *) findOutputWithAddress:(NSString *)a andPort:(int)p	{
	if (a == nil)
		return nil;
	
	OSCOutPort		*foundPort = nil;
	NSEnumerator	*it;
	OSCOutPort		*portPtr = nil;
	
	pthread_rwlock_rdlock(&outPortLock);
		it = [outPortArray objectEnumerator];
		while ((portPtr = [it nextObject]) && (foundPort == nil))	{
			if (([[portPtr addressString] isEqualToString:a]) && ([portPtr port] == p))	{
				foundPort = portPtr;
			}
		}
	pthread_rwlock_unlock(&outPortLock);
	
	return foundPort;
}
- (OSCOutPort *) findOutputForIndex:(int)i	{
	if ((i<0) || (i>=[outPortArray count]))
		return nil;
	OSCOutPort		*returnMe = nil;
	pthread_rwlock_rdlock(&outPortLock);
		returnMe = [outPortArray objectAtIndex:i];
	pthread_rwlock_unlock(&outPortLock);
	return returnMe;
}
- (OSCInPort *) findInputWithZeroConfName:(NSString *)n	{
	if (n == nil)
		return nil;
	
	id				foundPort = nil;
	NSEnumerator	*it;
	id				anObj;
	id				zeroConfDest = nil;
	
	pthread_rwlock_rdlock(&inPortLock);
		it = [inPortArray objectEnumerator];
		while ((anObj = [it nextObject]) && (foundPort == nil))	{
			zeroConfDest = [anObj zeroConfDest];
			if (zeroConfDest != nil)	{
				if ([n isEqualToString:[zeroConfDest name]])
					foundPort = anObj;
			}
		}
	pthread_rwlock_unlock(&inPortLock);
	return foundPort;
}
- (void) removeInput:(id)p	{
	if (p == nil)
		return;
	[(OSCInPort *)p stop];
	pthread_rwlock_wrlock(&inPortLock);
		[inPortArray removeObject:p];
	pthread_rwlock_unlock(&inPortLock);
}
- (void) removeOutput:(id)p	{
	if (p == nil)
		return;
	pthread_rwlock_wrlock(&outPortLock);
		[outPortArray removeObject:p];
	pthread_rwlock_unlock(&outPortLock);
}
- (NSArray *) outPortLabelArray	{
	NSMutableArray		*returnMe = [NSMutableArray arrayWithCapacity:0];
	NSEnumerator		*it;
	OSCOutPort			*portPtr;
	
	pthread_rwlock_rdlock(&outPortLock);
		it = [outPortArray objectEnumerator];
		while (portPtr = [it nextObject])	{
			if ([portPtr portLabel] != nil)	{
				[returnMe addObject:[portPtr portLabel]];
			}
		}
	pthread_rwlock_unlock(&outPortLock);
	
	return returnMe;
}
/*===================================================================================*/
#pragma mark --------------------- subclassable methods for customization
/*------------------------------------*/
/*!
	by default, this method returns [OSCInPort class].  it’s called when creating an input port. this method exists so if you subclass OSCInPort you can override this method to have your manager create your custom subclass with the default port creation methods
*/
- (id) inPortClass	{
	return [OSCInPort class];
}
- (NSString *) inPortLabelBase	{
	return [NSString stringWithString:@"VVOSC"];
}
/*!
	by default, this method returns [OSCOutPort class].  it’s called when creating an input port. this method exists so if you subclass OSCOutPort you can override this method to have your manager create your custom subclass with the default port creation methods
*/
- (id) outPortClass	{
	return [OSCOutPort class];
}
/*===================================================================================*/
#pragma mark --------------------- misc.
/*------------------------------------*/
- (id) delegate	{
	return delegate;
}
- (void) setDelegate:(id)n	{
	delegate = n;
}
- (NSMutableArray *) inPortArray	{
	return inPortArray;
}
- (NSMutableArray *) outPortArray	{
	return outPortArray;
}


@end

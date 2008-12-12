//
//  OSCInPortRetainsRaw.m
//  VVOSC
//
//  Created by bagheera on 10/3/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "OSCInPortRetainsRaw.h"


@implementation OSCInPortRetainsRaw


- (id) initWithPort:(short)p labelled:(NSString *)l	{
	//NSLog(@"OSCInPortRetainsRaw:initWithPort:labelled:");
	self = [super initWithPort:p labelled:l];
	packetStringArray = [[NSMutableArray arrayWithCapacity:0] retain];
	return self;
}
- (void) dealloc	{
	if (packetStringArray != nil)	{
		[packetStringArray release];
		packetStringArray = nil;
	}
	[super dealloc];
}
/*
	this formats a bunch of strings based on the raw data, stores them,
	then lets the super do it's thing.  the strings it formats are used
	for displaying the raw OSC data which has been received.
*/
- (void) parseRawBuffer:(unsigned char *)b ofMaxLength:(int)l	{
	NSMutableDictionary		*mutDict = [NSMutableDictionary dictionaryWithCapacity:0];
	NSMutableString			*mutString = nil;
	int						bundleIndexCount;
	unsigned char			*charPtr = b;
	
	//	assemble a string
	mutString = [NSMutableString stringWithCapacity:0];
	[mutString appendString:@"***************\r"];
	for (bundleIndexCount = 0; bundleIndexCount < (l/4); ++bundleIndexCount)	{
		[mutString appendFormat:@"(%d)\t\t%c\t%c\t%c\t%c\r",bundleIndexCount*4, charPtr[bundleIndexCount*4], charPtr[bundleIndexCount*4+1], charPtr[bundleIndexCount*4+2], charPtr[bundleIndexCount*4+3]];
	}
	//	add the string to the dict
	[mutDict setObject:[[mutString copy] autorelease] forKey:@"char"];
	
	
	mutString = [NSMutableString stringWithCapacity:0];
	[mutString appendString:@"***************\r"];
	for (bundleIndexCount = 0; bundleIndexCount < (l/4); ++bundleIndexCount)	{
		[mutString appendFormat:@"(%d)\t\t%X\t%X\t%X\t%X\r",bundleIndexCount*4, charPtr[bundleIndexCount*4], charPtr[bundleIndexCount*4+1],charPtr[bundleIndexCount*4+2],charPtr[bundleIndexCount*4+3]];
	}
	[mutDict setObject:[[mutString copy] autorelease] forKey:@"hex"];
	
	
	mutString = [NSMutableString stringWithCapacity:0];
	[mutString appendString:@"***************\r"];
	for (bundleIndexCount = 0; bundleIndexCount < (l/4); ++bundleIndexCount)	{
		[mutString appendFormat:@"(%d)\t\t%d\t%d\t%d\t%d\r",bundleIndexCount*4, charPtr[bundleIndexCount*4], charPtr[bundleIndexCount*4+1],charPtr[bundleIndexCount*4+2],charPtr[bundleIndexCount*4+3]];
	}
	[mutDict setObject:[[mutString copy] autorelease] forKey:@"dec"];
	
	
	//	add the dict to the array of packet string dicts
	[packetStringArray addObject:mutDict];
	
	//	make sure there aren't more than 25 dicts in the array
	while ([packetStringArray count] > 25)
		[packetStringArray removeObjectAtIndex:0];
	
	//	tell the super to parse the raw data
	[super parseRawBuffer:b ofMaxLength:l];
}
/*

*/
- (void) handleParsedScratchDict:(NSDictionary *)d	{
	//NSLog(@"OSCInPortRetainsRaw:handleParsedScratchDict:");
	NSMutableString		*mutString = [NSMutableString stringWithCapacity:0];
	NSEnumerator		*it = [[d allKeys] objectEnumerator];
	NSEnumerator		*altIt = nil;
	NSString			*key = nil;
	NSArray				*valArray = nil;
	id					anObj;
	
	[mutString appendString:@"***************"];
	while (key = [it nextObject])	{
		//NSLog(@"\t%@",key);
		[mutString appendFormat:@"\r%@-",key];
		valArray = [d objectForKey:key];
		altIt = [valArray objectEnumerator];
		while (anObj = [altIt nextObject])	{
			[mutString appendFormat:@"\r\t%@",anObj];
		}
	}
	[[packetStringArray lastObject] setObject:mutString forKey:@"coalesced"];
	[super handleParsedScratchDict:d];
}
- (void) handleScratchArray:(NSArray *)a	{
	NSMutableString		*mutString = [NSMutableString stringWithCapacity:0];
	NSEnumerator		*it = [a objectEnumerator];
	AddressValPair		*anObj;
	
	[mutString appendString:@"***************"];
	while (anObj = [it nextObject])	{
		[mutString appendFormat:@"\r%@ : %@",[anObj address],[anObj val]];
	}
	[[packetStringArray lastObject] setObject:mutString forKey:@"serial"];
	[super handleScratchArray:a];
}

- (NSMutableArray *) packetStringArray	{
	return packetStringArray;
}
- (void) setPacketStringArray:(NSArray *)a	{
	[packetStringArray removeAllObjects];
	if ((a != nil) && ([a count] > 0))	{
		[packetStringArray addObjectsFromArray:a];
	}
}


@end







































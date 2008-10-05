//
//  OSCPacket.m
//  OSC
//
//  Created by bagheera on 9/20/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "OSCPacket.h"




@implementation OSCPacket


+ (void) parseRawBuffer:(unsigned char *)b ofMaxLength:(int)l toInPort:(id)p	{
	//	this stuff prints out the buffer- it's very, very useful.
	/*
	printf("******************************\n");
	int				bundleIndexCount;
	unsigned char	*bufferCharPtr=b;
	for (bundleIndexCount=0; bundleIndexCount<(l/4); ++bundleIndexCount)	{
		printf("\t(%ld)\t\t%c\t%c\t%c\t%c\t\t%ld\t\t%ld\t\t%ld\t\t%ld\n",bundleIndexCount * 4,
			*(bufferCharPtr+bundleIndexCount*4), *(bufferCharPtr+bundleIndexCount*4+1), *(bufferCharPtr+bundleIndexCount*4+2), *(bufferCharPtr+bundleIndexCount*4+3),
			*(bufferCharPtr+bundleIndexCount*4), *(bufferCharPtr+bundleIndexCount*4+1), *(bufferCharPtr+bundleIndexCount*4+2), *(bufferCharPtr+bundleIndexCount*4+3));
	}
	printf("******************************\n");
	*/
	
	unsigned char	*buffPtr = b;
	if (buffPtr[0] == '#')	{
		[OSCBundle
			parseRawBuffer:b
			ofMaxLength:l
			toInPort:p];
	}
	else if (buffPtr[0] == '/')	{
		[OSCMessage
			parseRawBuffer:b
			ofMaxLength:l
			toInPort:p];
	}
}
+ (id) createWithContent:(id)c	{
	OSCPacket		*returnMe = [[OSCPacket alloc] initWithContent:c];
	if (returnMe == nil)
		return nil;
	return [returnMe autorelease];
}
- (id) initWithContent:(id)c	{
	self = [super init];
	bufferLength = [c bufferLength];
	payload = NULL;
	if (bufferLength < 1)	{
		[self release];
		return nil;
	}
	payload = malloc(bufferLength * sizeof(unsigned char));
	memset(payload,'\0',bufferLength);
	[c writeToBuffer:payload];
	return self;
}
- (void) dealloc	{
	//NSLog(@"OSCPacket:dealloc:");
	bufferLength = 0;
	if (payload != NULL)
		free(payload);
	payload = NULL;
	[super dealloc];
}

- (int) bufferLength	{
	return bufferLength;
}
- (unsigned char *) payload	{
	return payload;
}


@end

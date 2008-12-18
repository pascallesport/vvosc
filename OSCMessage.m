//
//  OSCMessage.m
//  OSC
//
//  Created by bagheera on 9/20/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "OSCMessage.h"
#import "OSCInPort.h"




@implementation OSCMessage


- (NSString *) description	{
	return [NSString stringWithFormat:@"<OSCMessage: %@\n%@",address,argArray];
}
+ (void) parseRawBuffer:(unsigned char *)b ofMaxLength:(int)l toInPort:(id)p	{
	//NSLog(@"OSCMessage:parseRawBuffer:ofMaxLength:toInPort:");
	if ((b == nil) || (l == 0) || (p == NULL))
		return;
	
	NSString		*address = nil;
	int				i, j;
	int				tmpIndex = 0;
	int				tmpInt;
	float			*tmpFloatPtr;
	long			tmpLong;
	int				msgTypeStartIndex = -1;
	int				msgTypeEndIndex = -1;
	
	
	
	/*
				parse the address string
	*/
	tmpIndex = -1;
	//	there's guaranteed to be a '\0' at the end of the address string- find the '\0'
	for (i=0; ((i<l) && (tmpIndex == (-1))); ++i)	{
		if (b[i] == '\0')
			tmpIndex = i;
	}
	//	get the actual address string
	if (tmpIndex != -1)
		address = [NSString stringWithCString:(char *)b encoding:NSASCIIStringEncoding];
	//	if i couldn't make the address string for any reason, return
	if (address == nil)	{
		NSLog(@"\t\terr: couldn't parse message address");
		return;
	}
	//	"tmpIndex" is the offset i'm currently reading from- so before i go further i
	//	have to account for any padding
	if (tmpIndex %4 == 0)
		msgTypeStartIndex = tmpIndex + 4;
	else
		msgTypeStartIndex = (4 - (tmpIndex % 4)) + tmpIndex;
	
	
	
	/*
				find the bounds of the type tag string
	*/
	//	if the item at the type tag string start isn't a comma, return immediately
	if (b[msgTypeStartIndex] != ',')	{
		NSLog(@"\t\terr: msg type tag string not present");
		return;
	}
	tmpIndex = -1;
	//	there's guaranteed to be a '\0' at the end of the type tag string- find it
	for (i=msgTypeStartIndex; ((i<l) && (tmpIndex == (-1))); ++i)	{
		if (b[i] == '\0')
			tmpIndex = i;
	}
	//	if i couldn't find the '\0', return
	if (tmpIndex == -1)	{
		NSLog(@"\t\terr: couldn't find the msg type end index");
		return;
	}
	msgTypeEndIndex = tmpIndex;
	//	"tmpIndex" is the offset i'm currently reading from- so before i go further i
	//	have to account for any padding
	if (tmpIndex % 4 == 0)
		tmpIndex = tmpIndex + 4;
	else
		tmpIndex = (4 - (tmpIndex %4)) + tmpIndex;
	
	
	
	/*
				now actually parse the contents of the message
	*/
	//	run through the type arguments (,ffis etc.)- for each type arg, pull data from the buffer
	for (i=msgTypeStartIndex; i<msgTypeEndIndex; ++i)	{
		switch(b[i])	{
			case 'i':			//	int32
				tmpLong = 0;
				for(j=0; j<4; ++j)	{
					tmpInt = b[tmpIndex+j];
					tmpLong = tmpLong | (tmpInt << ((3-j)*8));
				}
				tmpInt = ntohl(tmpLong);
				[p addValue:[NSNumber numberWithInt:tmpInt] toAddressPath:address];
				//NSLog(@"\t\t%d",tmpInt);
				tmpIndex = tmpIndex + 4;
				break;
			case 'f':			//	float32
				tmpInt = ntohl(*((long *)(b+tmpIndex)));
				tmpFloatPtr = (float *)&tmpInt;
				[p addValue:[NSNumber numberWithFloat:*tmpFloatPtr] toAddressPath:address];
				//NSLog(@"\t\t%f",*tmpFloatPtr);
				tmpIndex = tmpIndex + 4;
				break;
			case 's':			//	OSC-string
			case 'S':			//	alternate type represented as an OSC-string
				tmpInt = -1;
				for (j=tmpIndex; (j<l) && (tmpInt == -1); ++j)	{
					if (*((char *)b+j) == '\0')	{
						tmpInt = j-1;
					}
				}
				//	according to the spec, if the contents of the OSC-string occupy the
				//	full "width" of the 4-byte-aligned struct that *is* OSC, then there's an entire
				//	4-byte-struct of '\0' to ensure that you know where that shit ends.
				//	of course, this means that i don't need to check for the modulus before applying it.
				
				[p addValue:[NSString stringWithCString:(char *)(b+tmpIndex) encoding:NSASCIIStringEncoding] toAddressPath:address];
				//NSLog(@"\t\t%@",[NSString stringWithCString:(char *)(b+tmpIndex) encoding:NSASCIIStringEncoding]);
				tmpIndex = tmpInt+1;
				tmpIndex = 4 - (tmpIndex % 4) + tmpIndex;
				break;
			case 'b':			//	OSC-blob
				break;
			case 'h':			//	64 bit big-endian two's complement integer
				tmpIndex = tmpIndex + 8;
				break;
			case 't':			//	OSC-timetag (64-bit/8 byte)
				tmpIndex = tmpIndex + 8;
				break;
			case 'd':			//	64 bit ("double") IEEE 754 floating point number
				tmpIndex = tmpIndex + 8;
				break;
			case 'c':			//	an ascii character, sent as 32 bits
				tmpIndex = tmpIndex + 4;
				break;
			case 'r':			//	32 bit RGBA color
				//NSLog(@"%d, %d, %d, %d",*((unsigned char *)b+tmpIndex),*((unsigned char *)b+tmpIndex+1),*((unsigned char *)b+tmpIndex+2),*((unsigned char *)b+tmpIndex+3));

#if IPHONE
				[p
					addValue:[UIColor
						colorWithRed:b[tmpIndex]/255.0
						green:b[tmpIndex+1]/255.0
						blue:b[tmpIndex+2]/255.0
						alpha:b[tmpIndex+3]/255.0]
					toAddressPath:address];
#else
				[p
					addValue:[NSColor
						colorWithCalibratedRed:b[tmpIndex]/255.0
						green:b[tmpIndex+1]/255.0
						blue:b[tmpIndex+2]/255.0
						alpha:b[tmpIndex+3]/255.0]
					toAddressPath:address];
#endif
				tmpIndex = tmpIndex + 4;
				break;
			case 'm':			//	4 byte MIDI message.  bytes from MSB to LSB are: port id, status byte, data1, data2
				tmpIndex = tmpIndex + 4;
				break;
			case 'T':			//	True.  no bytes are allocated in the argument data!
				[p addValue:[NSNumber numberWithBool:YES] toAddressPath:address];
				break;
			case 'F':			//	False.  no bytes are allocated in the argument data!
				[p addValue:[NSNumber numberWithBool:NO] toAddressPath:address];
				break;
			case 'N':			//	Nil.  no bytes are allocated in the argument data!
				break;
			case 'I':			//	Infinitum.  no bytes are allocated in the argument data!
				break;
		}
	}
	
}
+ (id) createMessageToAddress:(NSString *)a	{
	OSCMessage		*returnMe = [[OSCMessage alloc] initWithAddress:a];
	if (returnMe == nil)
		return nil;
	return [returnMe autorelease];
}
- (id) initWithAddress:(NSString *)a	{
	if (a == nil)	{
		[self release];
		return nil;
	}
	pthread_rwlockattr_t		attr;
	self = [super init];
	//	if the address doesn't start with a "/", i need to add one
	if (*[a cStringUsingEncoding:NSASCIIStringEncoding] != '/')
		address = [[NSString stringWithFormat:@"/%@",a] retain];
	else
		address = [a retain];
	typeArray = [[NSMutableArray arrayWithCapacity:0] retain];
	argArray = [[NSMutableArray arrayWithCapacity:0] retain];
	pthread_rwlockattr_init(&attr);
	pthread_rwlockattr_setpshared(&attr, PTHREAD_PROCESS_SHARED);
	pthread_rwlock_init(&lock, &attr);
	return self;
}
- (void) dealloc	{
	//NSLog(@"OSCMessage:dealloc:");
	if (address != nil)
		[address release];
	address = nil;
	if (typeArray != nil)
		[typeArray release];
	typeArray = nil;
	if (argArray != nil)
		[argArray release];
	argArray = nil;
	pthread_rwlock_destroy(&lock);
	[super dealloc];
}

- (void) addInt:(int)n	{
	//NSLog(@"OSCMessage:addInt: ... %d",n);
	[typeArray addObject:[NSString stringWithString:@"i"]];
	[argArray addObject:[NSNumber numberWithInt:n]];
}
- (void) addFloat:(float)n	{
	//NSLog(@"OSCMessage:addFloat:");
	[typeArray addObject:[NSString stringWithString:@"f"]];
	[argArray addObject:[NSNumber numberWithFloat:n]];
}

#if IPHONE
- (void) addColor:(UIColor *)c	{
#else
- (void) addColor:(NSColor *)c	{
#endif

	if (c != nil)	{
		[typeArray addObject:[NSString stringWithString:@"r"]];
		[argArray addObject:c];
	}
}

- (void) addBOOL:(BOOL)n	{
	if (n)
		[typeArray addObject:[NSString stringWithString:@"T"]];
	else
		[typeArray addObject:[NSString stringWithString:@"F"]];
}

- (void) addString:(NSString *)n	{
	//NSLog(@"OSCMessage:addString: ... %@",n);
	if (n != nil)	{
		[typeArray addObject:[NSString stringWithString:@"s"]];
		[argArray addObject:n];
	}
}

- (int) bufferLength	{
	//NSLog(@"OSCMessage:bufferLength:");
	int		addressLength;
	int		typeLength;
	int		argLength;
	
	//	length of the address (round up to nearest 4 bytes)
	addressLength = [address length];
	addressLength = ((addressLength%4)!=0) ? 4-(addressLength%4)+addressLength : addressLength+4;
	//	length of the number of types + 1 (the "+ 1" is the comma)- round up to nearest 4 bytes
	typeLength = [typeArray count] + 1;
	typeLength = ((typeLength%4)!=0) ? 4-(typeLength%4)+typeLength : typeLength+4;
	//	length of the contents of the various arguments (eached rounded up to neares 4 bytes)
	NSEnumerator		*typeIt = [typeArray objectEnumerator];
	NSEnumerator		*argIt = [argArray objectEnumerator];
	NSString			*typePtr;
	id					argPtr;
	char				typeChar;
	int					tmpInt;
	
	argLength = 0;
	while ((typePtr = [typeIt nextObject]) && (argPtr = [argIt nextObject]))	{
		typeChar = *[typePtr cStringUsingEncoding:NSASCIIStringEncoding];
		switch (typeChar)	{
			case 'i':			//	int32
				argLength = argLength + 4;
				break;
			case 'f':			//	float32
				argLength = argLength + 4;
				break;
			case 's':			//	OSC-string
			case 'S':			//	alternate type represented as an OSC-string
				tmpInt = [argPtr length];
				//	figure out how long the string is- if it's an even multiple of 4
				if (tmpInt%4 == 0)	{
					//	add a 4-byte stride of padding
					argLength = argLength + (tmpInt + 4);
				}
				//	else round up to the nearest 4-byte strid
				else	{
					argLength = argLength + (4-(tmpInt%4)+tmpInt);
				}
				break;
			case 'b':			//	OSC-blob
				break;
			case 'h':			//	64 bit big-endian two's complement integer
				argLength = argLength + 8;
				break;
			case 't':			//	OSC-timetag (64-bit/8 byte)
				argLength = argLength + 8;
				break;
			case 'd':			//	64 bit ("double") IEEE 754 floating point number
				argLength = argLength + 8;
				break;
			case 'c':			//	an ascii character, sent as 32 bits
				argLength = argLength + 4;
				break;
			case 'r':			//	32 bit RGBA color
				argLength = argLength + 4;
				break;
			case 'm':			//	4 byte MIDI message.  bytes from MSB to LSB are: port id, status byte, data1, data2
				argLength = argLength + 4;
				break;
			case 'T':			//	True.  no bytes are allocated in the argument data!
				break;
			case 'F':			//	False.  no bytes are allocated in the argument data!
				break;
			case 'N':			//	Nil.  no bytes are allocated in the argument data!
				break;
			case 'I':			//	Infinitum.  no bytes are allocated in the argument data!
				break;
		}
	}
	
	return addressLength + typeLength + argLength;
}
- (void) writeToBuffer:(unsigned char *)b	{
	if (b == NULL)
		return;
	
	int					j;
	NSEnumerator		*typeIt;
	NSEnumerator		*argIt;
	NSString			*typePtr;
	id					argPtr;
	char				typeChar;
	int					writeOffset = 0;
	float				tmpFloat = 0.0;
	//uint32				tmpUInt = 0;
	unsigned char		tmpChar = 0;
	long				tmpLong;
	unsigned char		*charPtr = NULL;
#if IPHONE
	CGColorRef			tmpColor;
	const CGFloat		*tmpCGFloatPtr;
#endif
	
	
	//	write the address (round up to nearest 4 bytes)
	strncpy((char *)b, [address cStringUsingEncoding:NSASCIIStringEncoding], [address length]);
	writeOffset = writeOffset + [address length];
	writeOffset = 4 - (writeOffset % 4) + writeOffset;
	//	write the type arguments
	*(b + writeOffset) = ',';
	++writeOffset;
	typeIt = [typeArray objectEnumerator];
	while (typePtr = [typeIt nextObject])	{
		*(b + writeOffset) = *[typePtr cStringUsingEncoding:NSASCIIStringEncoding];
		++writeOffset;
	}
	writeOffset = 4 - (writeOffset % 4) + writeOffset;
	//	write the contents of the actual arguments
	typeIt = [typeArray objectEnumerator];
	argIt = [argArray objectEnumerator];
	while ((typePtr = [typeIt nextObject]) && (argPtr = [argIt nextObject]))	{
		typeChar = *[typePtr cStringUsingEncoding:NSASCIIStringEncoding];
		switch (typeChar)	{
			case 'i':			//	int32
				tmpLong = [argPtr intValue];
				tmpLong = htonl(tmpLong);
				
				for (j=0; j<4; ++j)	{
					tmpChar = 255 & (tmpLong >> ((3-j)*8));
					b[writeOffset+j] = 255 & (tmpLong >> ((3-j)*8));
				}
				
				writeOffset = writeOffset + 4;
				break;
			case 'f':			//	float32
				tmpFloat = [argPtr floatValue];
				tmpLong = htonl(*((long *)(&tmpFloat)));
				strncpy((char *)(b + writeOffset), (char *)(&tmpLong), 4);
				writeOffset = writeOffset + 4;
				break;
			case 's':			//	OSC-string
			case 'S':			//	alternate type represented as an OSC-string
				tmpLong = [argPtr length];
				charPtr = (unsigned char *)[argPtr cStringUsingEncoding:NSASCIIStringEncoding];
				strncpy((char *)(b+writeOffset),(char *)charPtr,tmpLong);
				
				writeOffset = writeOffset + tmpLong;
				if (tmpLong%4 == 0)
					writeOffset = writeOffset + 4;
				else
					writeOffset = writeOffset + (4 - (writeOffset % 4));
				break;
			case 'b':			//	OSC-blob
				break;
			case 'h':			//	64 bit big-endian two's complement integer
				break;
			case 't':			//	OSC-timetag (64-bit/8 byte)
				break;
			case 'd':			//	64 bit ("double") IEEE 754 floating point number
				break;
			case 'c':			//	an ascii character, sent as 32 bits
				break;
			case 'r':			//	32 bit RGBA color

#if IPHONE
				tmpColor = [argPtr CGColor];
				tmpCGFloatPtr = CGColorGetComponents(tmpColor);
				
				tmpChar = *(tmpCGFloatPtr) * 255.0;
				b[writeOffset] = tmpChar;
				tmpChar = *(tmpCGFloatPtr+1) * 255.0;
				b[writeOffset+1] = tmpChar;
				tmpChar = *(tmpCGFloatPtr+2) * 255.0;
				b[writeOffset+2] = tmpChar;
				tmpChar = *(tmpCGFloatPtr+3) * 255.0;
				b[writeOffset+3] = tmpChar;
#else
				tmpChar = [argPtr redComponent] * 255.0;
				b[writeOffset] = tmpChar;
				tmpChar = [argPtr greenComponent] * 255.0;
				b[writeOffset+1] = tmpChar;
				tmpChar = [argPtr blueComponent] * 255.0;
				b[writeOffset+2] = tmpChar;
				tmpChar = [argPtr alphaComponent] * 255.0;
				b[writeOffset+3] = tmpChar;
#endif
				
				writeOffset = writeOffset + 4;
				break;
			case 'm':			//	4 byte MIDI message.  bytes from MSB to LSB are: port id, status byte, data1, data2
				break;
			case 'T':			//	True.  no bytes are allocated in the argument data!
				break;
			case 'F':			//	False.  no bytes are allocated in the argument data!
				break;
			case 'N':			//	Nil.  no bytes are allocated in the argument data!
				break;
			case 'I':			//	Infinitum.  no bytes are allocated in the argument data!
				break;
		}
	}
}


@end

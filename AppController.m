//
//  AppController.m
//  OSC
//
//  Created by bagheera on 9/20/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "AppController.h"




@implementation AppController


- (id) init	{
	self = [super init];
	//	make an osc manager- i'm using "MyOSCManager" because i'm using a custom in-port
	manager = [[MyOSCManager alloc] init];
	return self;
}

- (void) awakeFromNib	{
	NSString		*ipFieldString;
	
	//	tell the osc manager to make an output port to a given IP and port
	outPort = [manager createNewOutputToAddress:@"127.0.0.1" atPort:1234];
	if (outPort == nil)
		NSLog(@"\t\terror creating output");
	//	tell the osc manager to make an input to receive from a given port
	inPort = [manager createNewInputForPort:1234];
	if (inPort == nil)
		NSLog(@"\t\terror creating input");
	//	set myself up as the in port's delegate
	[inPort setDelegate:self];
	
	ipFieldString = [NSString stringWithFormat:@"%@ port 1234",[[self ipAddressArray] objectAtIndex:0]];
	[receivingAddressField setStringValue:ipFieldString];
}

- (void) oscMessageReceived:(NSDictionary *)d	{
	if (d == nil)
		return;
	//NSLog(@"%@",d);
	[self displayPackets];
}
- (void) displayPackets	{
	NSArray				*localPacketArray = [NSArray arrayWithArray:[(OSCInPortRetainsRaw *)inPort packetStringArray]];
	NSEnumerator		*it = [localPacketArray reverseObjectEnumerator];
	NSDictionary		*dictPtr;
	NSMutableString		*mutString = [NSMutableString stringWithCapacity:0];
	NSString			*localKey = nil;
	
	//	figure out what kind of string i'm going to be assembling
	switch ([displayTypeRadioGroup selectedColumn])	{
		case 0:		//	parsed
			localKey = [NSString stringWithString:@"parsed"];
			break;
		case 1:		//	char
			localKey = [NSString stringWithString:@"char"];
			break;
		case 2:		//	dec
			localKey = [NSString stringWithString:@"dec"];
			break;
		case 3:		//	hex
			localKey = [NSString stringWithString:@"hex"];
			break;
	}
	//	assemble a string from the custom osc in port
	while (dictPtr = [it nextObject])	{
		//NSLog(@"%@",dictPtr);
		if ([dictPtr objectForKey:localKey] != nil)
			[mutString appendFormat:@"%@\n",[dictPtr objectForKey:localKey]];
	}
	//	push the assembled string to the view
	[receivingTextView performSelectorOnMainThread:@selector(setString:) withObject:[[mutString copy] autorelease] waitUntilDone:NO];
}

- (IBAction) setupFieldUsed:(id)sender	{
	//NSLog(@"AppController:setupFieldUsed:");
	[outPort setAddressString:[ipField stringValue]];
	[ipField setStringValue:[outPort addressString]];
	
	[outPort setPort:[portField intValue]];
	[portField setStringValue:[NSString stringWithFormat:@"%d",[outPort port]]];
}
- (IBAction) valueFieldUsed:(id)sender	{
	//NSLog(@"AppController:valueFieldUsd:");
	OSCMessage		*msg = nil;
	OSCBundle		*bundle = nil;
	OSCPacket		*packet = nil;
	
	//	make a bundle
	bundle = [OSCBundle create];
	//	make a message to the specified address
	msg = [OSCMessage createMessageToAddress:[oscAddressField stringValue]];
	//	add the message to the bundle (i can still add to the msg/bundle)
	[bundle addElement:msg];
	
	
	if (sender == floatSlider)	{
		[msg addFloat:[floatSlider floatValue]];
	}
	else if (sender == intField)	{
		[msg addInt:[intField intValue]];
	}
	else if (sender == colorWell)	{
		[msg addColor:[colorWell color]];
	}
	else if (sender == trueButton)	{
		[msg addBOOL:YES];
	}
	else if (sender == falseButton)	{
		[msg addBOOL:NO];
	}
	else if (sender == stringField)	{
		[msg addString:[stringField stringValue]];
	}
	
	//	make a packet from the buffer- as soon as you do this, the actual packet is made
	packet = [OSCPacket createWithContent:bundle];
	//	tell the out port to send the packet
	[outPort sendThisPacket:packet];
}
- (IBAction) displayTypeMatrixUsed:(id)sender	{
	[self displayPackets];
}

- (IBAction) intTest:(id)sender	{
	NSLog(@"AppController:intTest:");
	OSCBundle		*bundle = nil;
	OSCBundle		*altBundle = nil;
	OSCBundle		*mainBundle = nil;
	OSCMessage		*msg1 = nil;
	OSCMessage		*msg2 = nil;
	OSCMessage		*msg3 = nil;
	OSCPacket		*pack = nil;
	
	
	mainBundle = [OSCBundle create];
	
	//	make a bundle with a single message of the appropriate type
	bundle = [OSCBundle create];
	msg1 = [OSCMessage createMessageToAddress:@"/singleInt"];
	[msg1 addInt:2147483647];
	[bundle addElement:msg1];
	//	make a bundle with several messages (with several vals each) of the appropriate type
	altBundle = [OSCBundle create];
	msg1 = [OSCMessage createMessageToAddress:@"/multipleInts1"];
	[msg1 addInt:1];
	[msg1 addInt:2];
	[msg1 addInt:3];
	msg2 = [OSCMessage createMessageToAddress:@"/multipleInts2"];
	[msg2 addInt:4];
	[msg2 addInt:5];
	[msg2 addInt:6];
	msg3 = [OSCMessage createMessageToAddress:@"/multiplierInts3"];
	[msg3 addInt:7];
	[msg3 addInt:8];
	[msg3 addInt:9];
	[altBundle addElement:msg1];
	[altBundle addElement:msg2];
	[altBundle addElement:msg3];
	//	also add the single-message bundle to the bundle with several messages
	[altBundle addElement:bundle];
	//	add them to the main bundle
	[mainBundle addElement:bundle];
	[mainBundle addElement:altBundle];
	
	//	create a packet from the bundle (this actually makes the buffer that you'll send)
	pack = [OSCPacket createWithContent:mainBundle];
	//	tell the out port to send the packet
	[outPort sendThisPacket:pack];
}
- (IBAction) floatTest:(id)sender	{
	NSLog(@"AppController:floatTest:");
	OSCBundle		*bundle = nil;
	OSCBundle		*altBundle = nil;
	OSCBundle		*mainBundle = nil;
	OSCMessage		*msg1 = nil;
	OSCMessage		*msg2 = nil;
	OSCMessage		*msg3 = nil;
	OSCPacket		*pack = nil;
	
	
	mainBundle = [OSCBundle create];
	
	//	make a bundle with a single message of the appropriate type
	bundle = [OSCBundle create];
	msg1 = [OSCMessage createMessageToAddress:@"/singleFloat"];
	[msg1 addFloat:1.1];
	[bundle addElement:msg1];
	//	make a bundle with several messages (with several vals each) of the appropriate type
	altBundle = [OSCBundle create];
	msg1 = [OSCMessage createMessageToAddress:@"/multipleFloats1"];
	[msg1 addFloat:2.1];
	[msg1 addFloat:3.2];
	[msg1 addFloat:4.3];
	msg2 = [OSCMessage createMessageToAddress:@"/multipleFloats2"];
	[msg2 addFloat:5.4];
	[msg2 addFloat:6.5];
	[msg2 addFloat:7.6];
	msg3 = [OSCMessage createMessageToAddress:@"/multiplierFloats3"];
	[msg3 addFloat:8.7];
	[msg3 addFloat:9.8];
	[msg3 addFloat:10.9];
	[altBundle addElement:msg1];
	[altBundle addElement:msg2];
	[altBundle addElement:msg3];
	//	also add the single-message bundle to the bundle with several messages
	[altBundle addElement:bundle];
	//	add them to the main bundle
	[mainBundle addElement:bundle];
	[mainBundle addElement:altBundle];
	
	//	create a packet from the bundle (this actually makes the buffer that you'll send)
	pack = [OSCPacket createWithContent:mainBundle];
	//	tell the out port to send the packet
	[outPort sendThisPacket:pack];
}
- (IBAction) colorTest:(id)sender	{
	NSLog(@"AppController:colorTest:");
	OSCBundle		*bundle = nil;
	OSCBundle		*altBundle = nil;
	OSCBundle		*mainBundle = nil;
	OSCMessage		*msg1 = nil;
	OSCMessage		*msg2 = nil;
	OSCMessage		*msg3 = nil;
	OSCPacket		*pack = nil;
	
	
	mainBundle = [OSCBundle create];
	
	//	make a bundle with a single message of the appropriate type
	bundle = [OSCBundle create];
	msg1 = [OSCMessage createMessageToAddress:@"/singleColor"];
	[msg1 addColor:[NSColor colorWithDeviceRed:0.0 green:0.0 blue:0.0 alpha:0.1]];
	[bundle addElement:msg1];
	//	make a bundle with several messages (with several vals each) of the appropriate type
	altBundle = [OSCBundle create];
	msg1 = [OSCMessage createMessageToAddress:@"/multipleColors1"];
	[msg1 addColor:[NSColor colorWithDeviceRed:0.0 green:0.0 blue:1.0 alpha:0.1]];
	[msg1 addColor:[NSColor colorWithDeviceRed:0.0 green:1.0 blue:0.0 alpha:0.1]];
	[msg1 addColor:[NSColor colorWithDeviceRed:0.0 green:1.0 blue:1.0 alpha:0.1]];
	msg2 = [OSCMessage createMessageToAddress:@"/multipleColors2"];
	[msg2 addColor:[NSColor colorWithDeviceRed:1.0 green:0.0 blue:0.0 alpha:0.1]];
	[msg2 addColor:[NSColor colorWithDeviceRed:1.0 green:0.0 blue:1.0 alpha:0.1]];
	[msg2 addColor:[NSColor colorWithDeviceRed:1.0 green:1.0 blue:0.0 alpha:0.1]];
	msg3 = [OSCMessage createMessageToAddress:@"/multiplierColors3"];
	[msg3 addColor:[NSColor colorWithDeviceRed:1.0 green:1.0 blue:1.0 alpha:0.1]];
	[msg3 addColor:[NSColor colorWithDeviceRed:0.0 green:0.0 blue:1.0 alpha:0.1]];
	[msg3 addColor:[NSColor colorWithDeviceRed:0.0 green:1.0 blue:0.0 alpha:0.1]];
	[altBundle addElement:msg1];
	[altBundle addElement:msg2];
	[altBundle addElement:msg3];
	//	also add the single-message bundle to the bundle with several messages
	[altBundle addElement:bundle];
	//	add them to the main bundle
	[mainBundle addElement:bundle];
	[mainBundle addElement:altBundle];
	
	//	create a packet from the bundle (this actually makes the buffer that you'll send)
	pack = [OSCPacket createWithContent:mainBundle];
	//	tell the out port to send the packet
	[outPort sendThisPacket:pack];
}
- (IBAction) stringTest:(id)sender	{
	NSLog(@"AppController:stringTest:");
	OSCBundle		*bundle = nil;
	OSCBundle		*altBundle = nil;
	OSCBundle		*mainBundle = nil;
	OSCMessage		*msg1 = nil;
	OSCMessage		*msg2 = nil;
	OSCMessage		*msg3 = nil;
	OSCPacket		*pack = nil;
	
	
	mainBundle = [OSCBundle create];
	
	
	//	make a bundle with a single message of the appropriate type
	bundle = [OSCBundle create];
	msg1 = [OSCMessage createMessageToAddress:@"/singleString"];
	[msg1 addString:@"singlestring"];
	[bundle addElement:msg1];
	//	make a bundle with several messages (with several vals each) of the appropriate type
	altBundle = [OSCBundle create];
	msg1 = [OSCMessage createMessageToAddress:@"/multipleStrings1"];
	[msg1 addString:@"first mult string"];
	[msg1 addString:@"second mult string"];
	[msg1 addString:@"third mult string"];
	msg2 = [OSCMessage createMessageToAddress:@"/multipleStrings2"];
	[msg2 addString:@"first mult string B"];
	[msg2 addString:@"second mult string B"];
	[msg2 addString:@"third mult string B"];
	msg3 = [OSCMessage createMessageToAddress:@"/multiplierStrings3"];
	[msg3 addString:@"first mult string 3"];
	[msg3 addString:@"second mult string 3"];
	[msg3 addString:@"third mult string 3"];
	[altBundle addElement:msg1];
	[altBundle addElement:msg2];
	[altBundle addElement:msg3];
	//	also add the single-message bundle to the bundle with several messages
	[altBundle addElement:bundle];
	//	add them to the main bundle
	[mainBundle addElement:bundle];
	[mainBundle addElement:altBundle];
	
	
	//	create a packet from the bundle (this actually makes the buffer that you'll send)
	pack = [OSCPacket createWithContent:mainBundle];
	//	tell the out port to send the packet
	[outPort sendThisPacket:pack];
}

- (NSArray *) ipAddressArray	{
	//NSLog(@"AppController:ipAddressArray:");
	NSArray				*addressArray = [[NSHost currentHost] addresses];
	NSCharacterSet		*charSet;
	NSRange				charSetRange;
	NSEnumerator		*addressIt;
	NSString			*addressPtr;
	NSMutableArray		*returnMe = [NSMutableArray arrayWithCapacity:0];
	
	charSet = [NSCharacterSet characterSetWithCharactersInString:@"abcdefABCDEF:%"];
	//	run through the array of addresses
	addressIt = [addressArray objectEnumerator];
	while (addressPtr = [addressIt nextObject])	{
		//	if the address has any alpha-numeric characters, don't add it to the list
		charSetRange = [addressPtr rangeOfCharacterFromSet:charSet];
		//NSLog(@"%@, %d %d",addressPtr,charSetRange.location,charSetRange.length);
		if ((charSetRange.length==0) && (charSetRange.location==NSNotFound))	{
			//	make sure i'm not adding 127.0.0.1!
			if (![addressPtr isEqualToString:@"127.0.0.1"])
				[returnMe addObject:addressPtr];
		}
	}
	return returnMe;
}


@end

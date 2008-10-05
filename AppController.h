//
//  AppController.h
//  OSC
//
//  Created by bagheera on 9/20/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <VVOSC/VVOSC.h>
#import "MyOSCManager.h"


@interface AppController : NSObject {
	OSCManager					*manager;
	OSCInPort					*inPort;
	OSCOutPort					*outPort;
	
	IBOutlet NSTextField		*receivingAddressField;
	IBOutlet NSTextView			*receivingTextView;
	
	IBOutlet NSTextField		*ipField;
	IBOutlet NSTextField		*portField;
	IBOutlet NSTextField		*oscAddressField;
	
	IBOutlet NSSlider			*floatSlider;
	IBOutlet NSTextField		*intField;
	IBOutlet NSColorWell		*colorWell;
	IBOutlet NSButton			*trueButton;
	IBOutlet NSButton			*falseButton;
	IBOutlet NSTextField		*stringField;
	
	IBOutlet NSMatrix			*displayTypeRadioGroup;
}

- (void) oscMessageReceived:(NSDictionary *)d;
- (void) displayPackets;

//	called when IP address or port field is used
- (IBAction) setupFieldUsed:(id)sender;
//	called when float/int/color/etc. field is used
- (IBAction) valueFieldUsed:(id)sender;
//	called when user changes display mode
- (IBAction) displayTypeMatrixUsed:(id)sender;

- (IBAction) intTest:(id)sender;
- (IBAction) floatTest:(id)sender;
- (IBAction) colorTest:(id)sender;
- (IBAction) stringTest:(id)sender;

- (NSArray *) ipAddressArray;

@end

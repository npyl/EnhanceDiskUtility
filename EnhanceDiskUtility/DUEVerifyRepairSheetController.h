//
//  DUEVerifyRepairSheetController.h
//  EnhanceDiskUtility
//
//  Created by Nickolas Pylarinos on 09/08/2017.
//  Copyright © 2017 ulcheats. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <Foundation/Foundation.h>

enum {
    kVerifySheetIdentifier,
    kRepairSheetIdentifier,
};

@interface DUEVerifyRepairSheetController : NSObject
{
    xpc_connection_t connection;
}

@property (assign) IBOutlet NSWindow *              sheet;
@property (assign) IBOutlet NSTextField *            logView;
@property (assign) IBOutlet NSButton *              doneButton;
@property (assign) IBOutlet NSProgressIndicator *   progressIndicator;

- (void)showSheet:(int)sheetIdentifier forMountPoint:(NSString*)mountPoint;
- (IBAction)closeSheet:(id)sender;

@end

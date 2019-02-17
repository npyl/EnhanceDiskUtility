//
//  DUEVerifyRepairSheetController.m
//  EnhanceDiskUtility
//
//  Created by Nickolas Pylarinos on 09/08/2017.
//  Copyright © 2017 ulcheats. All rights reserved.
//

#import "DUEVerifyRepairSheetController.h"
#import "ANSIEscapeHelper/AMR_ANSIEscapeHelper.h"


@implementation DUEVerifyRepairSheetController

- (void)log:(NSString *)string
{
    if (string == nil)
        return;
    
    /*
     * Get a string with ANSI-escape-sequences and
     * convert it to an attributed string that can
     * be logged to the DUEnhance `logView`.
     */
    
    /*
     * make this static so that we dont allocate
     * it everytime we try to log something and
     * thus reduce overhead
     */
    static AMR_ANSIEscapeHelper *ansiEscapeHelper = nil;
    
    if (!ansiEscapeHelper) {
        ansiEscapeHelper = [[AMR_ANSIEscapeHelper alloc] init];
        
        // set colors & font to use to ansiEscapeHelper
        NSDictionary *colorPrefDefaults = [NSDictionary dictionaryWithObjectsAndKeys:
                                           [NSNumber numberWithInt:AMR_SGRCodeFgBlack], kANSIColorPrefKey_FgBlack,
                                           [NSNumber numberWithInt:AMR_SGRCodeFgWhite], kANSIColorPrefKey_FgWhite,
                                           [NSNumber numberWithInt:AMR_SGRCodeFgRed], kANSIColorPrefKey_FgRed,
                                           [NSNumber numberWithInt:AMR_SGRCodeFgGreen], kANSIColorPrefKey_FgGreen,
                                           [NSNumber numberWithInt:AMR_SGRCodeFgYellow], kANSIColorPrefKey_FgYellow,
                                           [NSNumber numberWithInt:AMR_SGRCodeFgBlue], kANSIColorPrefKey_FgBlue,
                                           [NSNumber numberWithInt:AMR_SGRCodeFgMagenta], kANSIColorPrefKey_FgMagenta,
                                           [NSNumber numberWithInt:AMR_SGRCodeFgCyan], kANSIColorPrefKey_FgCyan,
                                           [NSNumber numberWithInt:AMR_SGRCodeBgBlack], kANSIColorPrefKey_BgBlack,
                                           [NSNumber numberWithInt:AMR_SGRCodeBgWhite], kANSIColorPrefKey_BgWhite,
                                           [NSNumber numberWithInt:AMR_SGRCodeBgRed], kANSIColorPrefKey_BgRed,
                                           [NSNumber numberWithInt:AMR_SGRCodeBgGreen], kANSIColorPrefKey_BgGreen,
                                           [NSNumber numberWithInt:AMR_SGRCodeBgYellow], kANSIColorPrefKey_BgYellow,
                                           [NSNumber numberWithInt:AMR_SGRCodeBgBlue], kANSIColorPrefKey_BgBlue,
                                           [NSNumber numberWithInt:AMR_SGRCodeBgMagenta], kANSIColorPrefKey_BgMagenta,
                                           [NSNumber numberWithInt:AMR_SGRCodeBgCyan], kANSIColorPrefKey_BgCyan,
                                           nil];
        
        NSUInteger iColorPrefDefaultsKey;
        NSData *colorData;
        NSString *thisPrefName;
        for (iColorPrefDefaultsKey = 0; iColorPrefDefaultsKey < [[colorPrefDefaults allKeys] count]; iColorPrefDefaultsKey++)
        {
            thisPrefName = [[colorPrefDefaults allKeys] objectAtIndex:iColorPrefDefaultsKey];
            colorData = [[NSUserDefaults standardUserDefaults] dataForKey:thisPrefName];
            if (colorData != nil)
            {
                NSColor *thisColor = (NSColor *)[NSUnarchiver unarchiveObjectWithData:colorData];
                [[ansiEscapeHelper ansiColors] setObject:thisColor forKey:[colorPrefDefaults objectForKey:thisPrefName]];
            }
        }
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        
        [self->_logView setBaseWritingDirection:NSWritingDirectionLeftToRight];
        
        [ansiEscapeHelper setFont:[self->_logView font]];
        
        // get attributed string and display it
        NSMutableAttributedString *attrStr = [[NSMutableAttributedString alloc] initWithAttributedString:self->_logView.attributedString];
        [attrStr appendAttributedString:[ansiEscapeHelper attributedStringWithANSIEscapedString:string]];
        
        [[self->_logView textStorage] setAttributedString:attrStr];
    });
    
}

NSString *kEnhanceDiskUtilityBundleIdentifier = @"ulcheats.EnhanceDiskUtility";

- (void)executeUtilityWithArguments:(NSArray*)arguments
{
    /*
     *  Find Bundle Folder
     */
    NSBundle *mainBundle = [NSBundle bundleWithIdentifier:kEnhanceDiskUtilityBundleIdentifier];
    NSString *bundleResources = [mainBundle resourcePath];
    
    if (!bundleResources)
    {
        NSLog(@"Error: failed to get bundle path.");
        return;
    }
    
    /*
     *  Root or Normal User ?
     */
    
    if (getuid() != 0)
    {
        /*
         *  Call the HelperCaller
         */
        
        NSString *helperCallerPath = [bundleResources stringByAppendingPathComponent:@"SMJobBlessHelperCaller.app/Contents/MacOS/SMJobBlessHelperCaller"];
        
        @try
        {
            NSTask *task = [[NSTask alloc] init];
            [task setLaunchPath:helperCallerPath];
            [task launch];
            [task waitUntilExit];
            
            /*
             * By design, SMJobBlessHelper-Caller is supposed
             * to return 0 if it succeded in launching the Helper
             */
            if ([task terminationStatus] != 0)
            {
                [self->_progressIndicator stopAnimation:nil];
                return;
            }
        }
        @catch (NSException *exception)
        {
            [self log:@"Ooops!"];
        }
    }
    
    /*
     *  Start IPC with Helper
     */
    __block BOOL finishedSuccessfully = NO;             /* must become YES when verify/repair finished */
    
    connection = xpc_connection_create_mach_service("org.npyl.EnhanceDiskUtility.SMJobBlessHelper", NULL, XPC_CONNECTION_MACH_SERVICE_PRIVILEGED);
    
    if (!connection)
    {
        NSLog(@"Failed to create XPC connection.");
        [self log:@"Failed to create XPC connection."];     // XXX this should be RED
        return;
    }
    
    xpc_connection_set_event_handler(connection, ^(xpc_object_t event) {
        xpc_type_t type = xpc_get_type(event);
        
        if (type == XPC_TYPE_ERROR)
        {
            if (event == XPC_ERROR_CONNECTION_INTERRUPTED)  { NSLog(@"XPC connection interupted."); }
            else if (event == XPC_ERROR_CONNECTION_INVALID) { NSLog(@"XPC connection invalid, releasing."); }
            else                                            { NSLog(@"Unexpected XPC connection error."); }
            
            if (!finishedSuccessfully)
            {
                [self log:@"\n\n \033[31mFailed to Repair/Verify Permissions; XPC connection problem"];
            }
            
            [self->_progressIndicator stopAnimation:nil];
        }
        else
        {
            const char *utilityData = xpc_dictionary_get_string(event, "utilityData");
            int64_t terminationStatus = xpc_dictionary_get_int64(event, "terminationStatus");
            
            if (!utilityData)
            {
                NSLog(@"Error: utilityData = null");
                return;
            }
            
            if (strcmp(utilityData, "FINISHED!") == 0)
            {
                if (terminationStatus == 0) // RepairPermissionsUtility exited with status 0 => SUCCESS
                {
                    /*
                     * tell the event handler that the XPC_ERROR_CONNECTION_INVALID
                     * that will follow is a sign all operations succeded, not an error
                     */
                    finishedSuccessfully = YES;
                }
                else
                {
                    NSLog(@"DUE: Error! RepairPermissionsUtility exited with status:%lld", terminationStatus);
                    [self log:@"RepairPermissions utility run into a problem! Check Console.app for more information."];
                }
                
                [self->_progressIndicator stopAnimation:nil];
            }
            else
            {
                /*
                 * Not a FINISH message; Just data to print
                 */
                NSLog(@"DUE: RECV");
                [self log:[NSString stringWithUTF8String:utilityData]];
            }
        }
    });
    
    xpc_connection_resume(connection);
    
    //
    //  Tell helper to run utility
    //
    const char* mode = [[arguments objectAtIndex:0] UTF8String];
    const char* mountPoint = [[arguments objectAtIndex:1] UTF8String];
    const char* repairPermissionsUtilityPath = [[mainBundle pathForResource:@"RepairPermissionsUtility" ofType:nil] UTF8String];
    
    /*
     * Construct a dictionary of the arguments
     */
    xpc_object_t initialMessage = xpc_dictionary_create(NULL, NULL, 0);
    xpc_dictionary_set_string(initialMessage, "mode", mode);
    xpc_dictionary_set_string(initialMessage, "mountPoint", mountPoint);
    xpc_dictionary_set_string(initialMessage, "RepairPermissionsUtilityPath", repairPermissionsUtilityPath);
    
    /*
     * Send the message
     */
    xpc_connection_send_message(connection, initialMessage);
}

/*
 *  void showSheet: int sheetIdentifier forMountPoint: NSString * mountPoint
 *
 *  sheetIdentifer is passed to tell our method to load the sheet residing in the VerifyRepairPermissions.xib but call
 *      the HelperCaller with arguments corresponding to "Verify" or "Repair".
 *      IT DOESNT load a different sheet for Verification and a different for Repairing...
 *
 */

- (void)showSheet:(int)sheetIdentifier forMountPoint:(NSString*)mountPoint
{
    NSArray *arguments = nil;
    
    switch (sheetIdentifier)
    {
        case kVerifySheetIdentifier:
            
            arguments = [NSArray arrayWithObjects:@"--verify", mountPoint, nil];
            
            break;
        case kRepairSheetIdentifier:
            
            arguments = [NSArray arrayWithObjects:@"--repair", mountPoint, nil];

            break;
        default:
            NSLog(@"DUE: Unexpected sheetIdentifier passed! Aborting! Why did this even happen?");
            break;
    }
    
    if (!_sheet)
        [[NSBundle bundleWithIdentifier:kEnhanceDiskUtilityBundleIdentifier] loadNibNamed:@"VerifyRepairPermissions" owner:self topLevelObjects:nil];
    
    [[NSApp mainWindow] beginSheet:self.sheet completionHandler:^(NSModalResponse returnCode) {
        [[NSApp mainWindow] endSheet:self.sheet];
    }];
    
    [_progressIndicator startAnimation:nil];
    
    /*
     *  Start the process
     */
    [self executeUtilityWithArguments:arguments];
}

- (IBAction)closeSheet:(id)sender
{
    [self.sheet close];
    
    //
    //  End the connection
    //
    if (connection)
    {
        NSLog(@"DUE: Canceling connection...");
        xpc_connection_cancel(connection);
    }
}

@end

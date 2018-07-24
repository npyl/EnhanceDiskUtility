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
    /*
     * Get a string with ASCII-escape-sequences and
     * convert it to an attributed string that can
     * be logged to the DUEnhance `logView`.
     */
    
    /*
     * make this static so that we dont allocate
     * it everytime we try to log something and
     * thus reduce overhead
     */
    static AMR_ANSIEscapeHelper *ansiEscapeHelper = nil;
    
    if (!ansiEscapeHelper)
        ansiEscapeHelper = [[AMR_ANSIEscapeHelper alloc] init];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        
        NSMutableAttributedString *tmp = [[NSMutableAttributedString alloc] initWithAttributedString:_logView.attributedStringValue];
        
        /* append new-ly converted string */
        [tmp appendAttributedString:[ansiEscapeHelper attributedStringWithANSIEscapedString:string]];
        
        _logView.attributedStringValue = tmp;
        
        /*
         * XXX if we reach an end of view flush the previous lines of the string so that we not hit an overflow
         */
    });
    
}

NSString *kEnhanceDiskUtilityBundleIdentifier = @"ulcheats.EnhanceDiskUtility";

- (void)executeUtilityWithArguments:(NSArray*)arguments
{
    /*
     *  Find Bundle Folder
     */
    
    [self log:@"\033[31mHELLOv2"];
    
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
                return;
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
            if (event == XPC_ERROR_CONNECTION_INTERRUPTED) {
                NSLog(@"XPC connection interupted.");
            } else if (event == XPC_ERROR_CONNECTION_INVALID) {
                NSLog(@"XPC connection invalid, releasing.");
            } else {
                NSLog(@"Unexpected XPC connection error.");
            }
            
            if (!finishedSuccessfully)
            {
                [self log:@"\n\n \033[31mDUE: Failed to Repair/Verify Permissions; XPC connection problem"];
            }
            
            [_progressIndicator stopAnimation:nil];
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
                
                [_progressIndicator stopAnimation:nil];
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
    
    [[NSApp mainWindow] beginSheet:self.sheet completionHandler:^(NSModalResponse returnCode) {}];
    
    [_progressIndicator startAnimation:nil];
    
    /*
     *  Start the process
     */
    [self executeUtilityWithArguments:arguments];
}

- (IBAction)closeSheet:(id)sender
{
    [[NSApp mainWindow] endSheet:self.sheet];
    self.sheet = nil;
    
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

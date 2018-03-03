//
//  DUEVerifyRepairSheetController.m
//  EnhanceDiskUtility
//
//  Created by Nickolas Pylarinos on 09/08/2017.
//  Copyright © 2017 ulcheats. All rights reserved.
//

// ** TODO ** Tell people about the apple SMJobBlessUtil.py file ( they can use??? )

#import "DUEVerifyRepairSheetController.h"


@implementation DUEVerifyRepairSheetController

@synthesize sheet = _sheet;
@synthesize logView = _logView;
@synthesize doneButton = _doneButton;
@synthesize progressIndicator = _progressIndicator;

NSString * kEnhanceDiskUtilityBundleIdentifier = @"ulcheats.EnhanceDiskUtility";

- (void)executeUtilityWithArguments:(NSArray*)arguments
{
    /*
     *  Find Bundle Folder
     */
    
    NSBundle * mainBundle = [NSBundle bundleWithIdentifier:kEnhanceDiskUtilityBundleIdentifier];
    NSString * bundleResources = [mainBundle resourcePath];
    
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
        
        NSString * helperCallerPath = [bundleResources stringByAppendingString:@"SMJobBlessHelperCaller.app/Contents/MacOS/SMJobBlessHelperCaller"];
        
        NSTask * task = [[NSTask alloc] init];
        [task setLaunchPath:helperCallerPath];
        [task launch];
        [task waitUntilExit];
        
        if ([task terminationStatus] != 0)
            return;
    }
    
    /*
     *  Start IPC with Helper
     */
    
    /* Find Resources folder */
    
    __block BOOL somethingFailed = NO;                  /* must not be YES */
    __block BOOL finishedSuccessfully = NO;             /* must become YES when verify/repair finished */
    
    
    connection = xpc_connection_create_mach_service("org.npyl.EnhanceDiskUtility.SMJobBlessHelper", NULL, XPC_CONNECTION_MACH_SERVICE_PRIVILEGED);
    
    if (!connection)
    {
        NSLog( @"Failed to create XPC connection." );
        return;
    }
    
    xpc_connection_set_event_handler(connection, ^(xpc_object_t event) {
        xpc_type_t type = xpc_get_type(event);
        
        if (type == XPC_TYPE_ERROR) {
            
            if (event == XPC_ERROR_CONNECTION_INTERRUPTED) {
                NSLog(@"XPC connection interupted.");
            } else if (event == XPC_ERROR_CONNECTION_INVALID) {
                NSLog(@"XPC connection invalid, releasing.");
            } else {
                NSLog(@"Unexpected XPC connection error.");
            }
            
            /*  if somethingFailed during STAGE1 or didn't finish successfully ( thus failed during STAGE2 ) */
            
            if (somethingFailed || !finishedSuccessfully)
            {
                NSLog( @"%@", somethingFailed ? @"Something went wrong during STAGE1 of XPC communication" : @"Something went wrong during STAGE2 of XPC communication" );
                _logView.stringValue = [_logView.stringValue stringByAppendingString:somethingFailed
                                ? @"Something went wrong during STAGE1 of XPC communication"
                                : @"Something went wrong during STAGE2 of XPC communication"];
            }
            
            
            [_progressIndicator stopAnimation:nil];
            
            
            //
            //  In case of any XPC error we dont have to cancel the connection here. ( neither anywhere else )
            //
            //  Upon invalidation / interruption during XPC communication all the following xpc-related calls will fail
            //  Thus the executeUtilityWithArguments() will return.
            //
            //  All XPC errors are handled appropriately by the SMJobBlessHelper
            //
        }
        else
        {    //======================    STAGE 2    ======================//
            
            
            const char * utilityData = xpc_dictionary_get_string( event, "utilityData" );
            int64_t terminationStatus = xpc_dictionary_get_int64( event, "terminationStatus" );
            
            if (!utilityData)
            {
                NSLog( @"Error: utilityData = null" );
                return;
            }
            
            //
            //  Got non-error-event from Helper! Check whether FINISH! or data
            //  |_  YES =>  Check if we got exit status=0
            //  |               |_  YES => Show log
            //  |               |_  NO  => Show error
            //  |_  NO  =>  It is data from the Utility =>  Print to textbox
            //
            
            if (strcmp(utilityData, "FINISHED!") == 0)
            {
                if (terminationStatus == 0) // RepairPermissionsUtility exited with status 0 => SUCCESS
                {
                    NSLog(@"Got RepairPermissionsUtility exit status=0");
                    
                    //
                    // Cool. Open RepairPermissionsUtility's log stored in /tmp
                    //
                    
                    NSError * err = nil;
                    NSString * str = [[NSString alloc] initWithContentsOfFile:@"/tmp/RepairPermissionsUtility.log" encoding:NSUTF8StringEncoding error:&err];
                    
                    if (!str)
                        return;
                    
                    NSLog(@"%@",str);
                    
                    /* give it to our scrol view */
                    _logView.stringValue = [_logView.stringValue stringByAppendingString:str];
                    
                    finishedSuccessfully = YES;     /* tell the event handler that the XPC_ERROR_CONNECTION_INVALID that will follow is a sign all operations succeded, not an error */
                    
                    [str release];
                }
                else
                {
                    NSLog( @"Error! RepairPermissionsUtility exited with status:%lld", terminationStatus );
                    _logView.stringValue = [_logView.stringValue stringByAppendingString:@"RepairPermissions utility run into a problem! Check Console.app for more information."];
                }
                
                [_progressIndicator stopAnimation:nil];
            }
            else
            {
                // TODO: must finish this...
                //
                //  Problem is when passing the parameter --output /tmp/RepairPermissions.log to RepairPermissionsUtility it does not give output ( or the output is not detectable? )
                //  I will see if I can find a solution to this so that we print the percentage at least :)
                //
                //  For this reason I disabled the pipe functionality in Helper ( This means less overhead for EnhanceDiskUtility which is a positive aspect )
                //
                
                //NSLog( @"%s", utilityData );    // dbg
            }
        }
    });
    
    xpc_connection_resume(connection);
    
    
    //======================    STAGE 1    ======================//
    
    
    //
    //  Tell helper to run utility
    //

    xpc_object_t initialMessage = xpc_dictionary_create(NULL, NULL, 0);
    
    const char* mode = [[arguments objectAtIndex:0] UTF8String];
    const char* mountPoint = [[arguments objectAtIndex:1] UTF8String];
    const char* repairPermissionsUtilityPath = [[mainBundle pathForResource:@"RepairPermissionsUtility" ofType:nil] UTF8String];
    
    
    //
    //  Construct a dictionary of the arguments
    //
    xpc_dictionary_set_string(initialMessage, "mode", mode);
    xpc_dictionary_set_string(initialMessage, "mountPoint", mountPoint);
    xpc_dictionary_set_string(initialMessage, "RepairPermissionsUtilityPath", repairPermissionsUtilityPath);
    
    
    xpc_connection_send_message_with_reply(connection, initialMessage, dispatch_get_main_queue(), ^(xpc_object_t event) {

        xpc_release(initialMessage);
        
        const char* responseForMode = xpc_dictionary_get_string( event, "mode" );
        const char* responseForMountPoint = xpc_dictionary_get_string( event, "mountPoint" );

        NSLog(@"respMode = %s\nrespMNTPoint = %s", responseForMode, responseForMountPoint );
        
        if ( !(responseForMode && responseForMountPoint) )
        {
            somethingFailed = YES;
            return;
        }
        
        if ( strcmp( responseForMode,        "GOT_MODE" )       != 0    ||
             strcmp( responseForMountPoint,  "GOT_MNTPOINT" )   != 0 )
        {
            NSLog( @"Failed to send correct mode or mountPoint to Helper via XPC." );
            
            somethingFailed = YES;
            xpc_connection_cancel(connection);
            return;
        }
    });
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
    NSArray * arguments = nil;
    
    switch ( sheetIdentifier )
    {
        case kVerifySheetIdentifier:
            
            arguments = [NSArray arrayWithObjects:@"--verify", mountPoint, nil];
            
            break;
        case kRepairSheetIdentifier:
            
            arguments = [NSArray arrayWithObjects:@"--repair", mountPoint, nil];

            break;
        default:
            NSLog(@"Unexpected sheetIdentifier passed! Aborting!");
            break;
    }
    
    if (!_sheet)
        [[NSBundle bundleWithIdentifier:kEnhanceDiskUtilityBundleIdentifier] loadNibNamed:@"VerifyRepairPermissions" owner:self topLevelObjects:nil];
    
    [[NSApp mainWindow] beginSheet:self.sheet completionHandler:^(NSModalResponse returnCode) {}];
    
    [_progressIndicator startAnimation:nil];
    
    /*
     *  Start the process
     */
    
    _logView.stringValue = [_logView.stringValue stringByAppendingString:@"Starting!"];
    
    [self executeUtilityWithArguments:arguments];                                           //
                                                                                            //  this sends data to the sheetScrollView from the RepairPermissionsUtility
                                                                                            //  once for any reason this ends the sheet waits there to be closed with a button
                                                                                            //
}

- (IBAction)closeSheet:(id)sender
{
    [[NSApp mainWindow] endSheet:self.sheet];
    self.sheet = nil;
    
    //
    //  Communication cleanup related
    //
    if (connection)
    {
        NSLog(@"releasing connection related...");
        xpc_connection_cancel(connection);
        xpc_release(connection);
    }
        
    dispatch_async(dispatch_get_main_queue(), ^{
        NSLog(@"Releasing sheet controller!");                      //
        [self release];                                             //  I cant think of another way to ensure the sheetController gets released the right time
                                                                    //
    });
}

@end

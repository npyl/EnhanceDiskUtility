//
//  DUEVerifyRepairSheetController.m
//  EnhanceDiskUtility
//
//  Created by Nickolas Pylarinos on 09/08/2017.
//  Copyright © 2017 ulcheats. All rights reserved.
//

// ** TODO ** Upon exit of DiskUtil we need to kill repairPermissions if running.   -- Must be done by the Helper not us
// ** TODO ** Tell people about the apple SMJobBlessUtil.py file ( they can use??? )


#import "DUEVerifyRepairSheetController.h"


@implementation DUEVerifyRepairSheetController


@synthesize sheet = _sheet;
@synthesize logTextField = _logTextField;
@synthesize doneButton = _doneButton;
@synthesize progressIndicator = _progressIndicator;


- (void)executeUtilityWithArguments:(NSArray*)arguments
{
    //
    //  Find Bundle Folder
    //
    
    NSString * kEnhanceDiskUtilityBundleIdentifier = @"ulcheats.EnhanceDiskUtility";
    NSString * bundlePath = [[NSBundle bundleWithIdentifier:kEnhanceDiskUtilityBundleIdentifier] bundlePath];
    
    
    if( !bundlePath )
    {
        NSLog( @"failed to get bundle path!" );
        return;
    }
    
    
    
    NSLog( @"BundlePath = %@", bundlePath );
    
    
    //
    //  Root or Normal User ?
    //
    
    if( getuid() == 0 )
        goto COMMUNICATIONS;
    
    
    //
    //  Call the HelperCaller
    //
    
    NSString * helperCallerPath = [bundlePath stringByAppendingString:@"/Contents/Resources/SMJobBlessHelperCaller.app/Contents/MacOS/SMJobBlessHelperCaller"];
    NSLog( @"HelperCallerPath = %@", helperCallerPath );
    
    NSTask * task = [[NSTask alloc] init];
    [task setLaunchPath:helperCallerPath];
    [task launch];
    [task waitUntilExit];
    
    if( [task terminationStatus] != 0 )
        return;
    
    


    
    
COMMUNICATIONS:
    {
        
        //
        //  Start IPC with Helper
        //
        
        //
        //  Find Resources folder
        //
        
        __block BOOL somethingFailed = NO;
        
        
        NSString * bundleResourcePath = [bundlePath stringByAppendingString:@"/Contents/Resources"];
        NSLog( @"ResourcePath = %@", bundleResourcePath );
        
        connection = xpc_connection_create_mach_service( "org.npyl.EnhanceDiskUtility.SMJobBlessHelper", NULL, XPC_CONNECTION_MACH_SERVICE_PRIVILEGED);
        
        if (!connection) {
            NSLog( @"Failed to create XPC connection." );
            return;
        }
        
        xpc_connection_set_event_handler(connection, ^(xpc_object_t event) {
            xpc_type_t type = xpc_get_type(event);
            
            if (type == XPC_TYPE_ERROR) {
                
                if (event == XPC_ERROR_CONNECTION_INTERRUPTED) {
                    NSLog( @"XPC connection interupted." );
                } else if (event == XPC_ERROR_CONNECTION_INVALID) {
                    NSLog( @"XPC connection invalid, releasing." );
                } else {
                    NSLog( @"Unexpected XPC connection error." );
                }
                
                // TODO: make this explanation better
                // -- ITS OK, we exit if we find a null string or something anyway so... ** TODO ** set a flag to force code to leave the -(void)executeUtilityWithArguments: function
                // -- We dont have to add code for this here.
            } else {
                //
                //
                //
                
                const char * utilityData = xpc_dictionary_get_string( event, "utilityData" );
                
                if (!utilityData)
                    return;
                
                if ( strcmp( utilityData, "FINISHED!" ) == 0 )
                {
                    //
                    // Cool. Open RepairPermissionsUtility's log stored in /tmp
                    //
                    
                    NSError * err = nil;
                    NSString * str = [[NSString alloc] initWithContentsOfFile:@"/tmp/RepairPermissionsUtility.log" encoding:NSUTF8StringEncoding error:&err];
                    
                    if (!str)
                        return;
                    
                    /* give it to our scrol view */
                    [_logTextField setScrollable:YES];
                    [_logTextField setEnabled:YES];
                    [_logTextField setPlaceholderString:str];
                    
                    [str release];
                } else {
                    char data[7];
                    int j = 0;
                    
                    for ( int i = 102; i < 109 && utilityData[ i ] != ' '; i++ )
                        data[ j++ ] = utilityData[ i ];
                    
                    NSLog( @"percentage: %s", data );
                    
                    /*
                     *  RepairPermissionsUtility Output Style:
                     *
                     *  Task output! \^[[1;39mStatus:	 \^[[0;39m\^[[1;39m[ULTRAFAST]\^[[0;39m Doing some wolf's magics...	\^[[1;39mProgress: \^[[0;39m41.29% [|]
                     */
                }
            }
        });
        
        xpc_connection_resume(connection);
        
        
        //
        //  Tell helper to run utility
        //
        
        
        xpc_object_t initialMessage = xpc_dictionary_create(NULL, NULL, 0);
        
        const char* mode = [[arguments objectAtIndex:0] UTF8String];
        const char* mountPoint = [[arguments objectAtIndex:1] UTF8String];
        const char* repairPermissionsUtilityPath = [[bundleResourcePath stringByAppendingString:@"/RepairPermissionsUtility"] UTF8String];
        
        
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
                
                
                xpc_connection_cancel(connection);
                
                somethingFailed = YES;
                return;
            }
        });
        
        if ( somethingFailed )
            NSLog( @"Something went wrong during communication with Helper" );
    
        
    }   // COMMUNICATIONS
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
    NSString * kEnhanceDiskUtilityBundleIdentifier = @"ulcheats.EnhanceDiskUtility";        // ** TODO ** This should reside in common.h
    NSArray * arguments = nil;
    
    
    switch ( sheetIdentifier ) {
        case kVerifySheetIdentifier:
            
            arguments = [[NSArray alloc] initWithObjects:@"--verify", mountPoint, nil];
            
            break;
        case kRepairSheetIdentifier:
            
            arguments = [[NSArray alloc] initWithObjects:@"--repair", mountPoint, nil];

            break;
        default:
            NSLog( @"Unexpected sheetIdentifier passed! Aborting!" );
            return;
            
            break;
    }
    
    if ( !_sheet )
        [[NSBundle bundleWithIdentifier:kEnhanceDiskUtilityBundleIdentifier] loadNibNamed:@"VerifyRepairPermissions" owner:self topLevelObjects:nil];
    
    [[NSApp mainWindow] beginSheet:self.sheet completionHandler:^(NSModalResponse returnCode) {}];
    
    [_progressIndicator startAnimation:nil];
    
    //
    //  Start the process
    //
    
    [self executeUtilityWithArguments:arguments];                                           //
                                                                                            //  this sends data to the sheetScrollView from the RepairPermissionsUtility
                                                                                            //  once for any reason this ends the sheet waits there to be closed with a button
                                                                                            //
    
    [_progressIndicator stopAnimation:nil];
}

- (IBAction)closeSheet:(id)sender
{
    [[NSApp mainWindow] endSheet:self.sheet];
    self.sheet = nil;
    
    //
    //  Communication cleanup related
    //
    if (connection) {
        NSLog( @"releasing connection related..." );
        xpc_connection_cancel(connection);
        xpc_release(connection);
    }
        
    dispatch_async(dispatch_get_main_queue(), ^{
        NSLog( @"Releasing sheet controller!" );                    //
        [self release];                                             //  I cant think of another way to ensure the sheetController gets released the right time
                                                                    //
    });
}

@end

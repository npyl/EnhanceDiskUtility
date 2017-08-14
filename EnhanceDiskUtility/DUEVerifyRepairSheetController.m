//
//  DUEVerifyRepairSheetController.m
//  EnhanceDiskUtility
//
//  Created by Nickolas Pylarinos on 09/08/2017.
//  Copyright © 2017 ulcheats. All rights reserved.
//

#import "DUEVerifyRepairSheetController.h"


@implementation DUEVerifyRepairSheetController

enum {
    kSUCCESS = 0,                   //  ** TODO ** PUT THESE IN COMMON.H as common DUEErrors
    
    kNO_BNDLPATH,
    kNO_HELPERCALLER_EXEC,
    kNO_HELPER_XPC_CONNECT,
};

@synthesize sheet = _sheet;
@synthesize logView = _logView;
@synthesize doneButton = _doneButton;
@synthesize progressIndicator = _progressIndicator;

- (instancetype)init
{
    self = [super init];
    if (self) {
        didFinishRepairOrVerifyJob = NO;
    }
    return self;
}

- (unsigned)executeUtilityWithArguments:(NSArray*)arguments
{
    // ** TODO ** Upon exit of DiskUtil we need to kill repairPermissions if running.
    // ** TODO ** Tell people about the apple SMJobBlessUtil.py file ( they can use??? )
    
    //
    //  Find Bundle Folder
    //
    
    NSString * kEnhanceDiskUtilityBundleIdentifier = @"ulcheats.EnhanceDiskUtility";
    NSString * bundlePath = [[NSBundle bundleWithIdentifier:kEnhanceDiskUtilityBundleIdentifier] bundlePath];
    
//    for( NSBundle * bndl in [NSBundle allBundles] )
//        if( [[bndl bundleIdentifier] isEqualToString:kEnhanceDiskUtilityBundleIdentifier ] )
//            bundlePath = [bndl bundlePath];
    
    if( !bundlePath )
    {
        NSLog( @"failed to get bundle path!" );
        return kNO_BNDLPATH;
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
        return kNO_HELPERCALLER_EXEC;
    
    
    
    
    
COMMUNICATIONS:
    {
        
        //
        //  Start IPC with Helper
        //
        
        //
        //  Find Resources folder
        //
        __block bool mustEndConnection = false;     //
                                                    //  ** TODO ** What does __block do?
                                                    //

        
        xpc_connection_t connection = xpc_connection_create_mach_service( "org.npyl.EnhanceDiskUtility.SMJobBlessHelper", NULL, XPC_CONNECTION_MACH_SERVICE_PRIVILEGED);
        
        if (!connection) {
            NSLog( @"Failed to create XPC connection." );
            return kNO_HELPER_XPC_CONNECT;
        }
        
        //
        //  Tell helper to run utility
        //
        
        xpc_object_t message = xpc_dictionary_create(NULL, NULL, 0);
        const char* request = "START";
        xpc_dictionary_set_string( message, "request", request );
        
        xpc_connection_send_message_with_reply( connection, message, dispatch_get_main_queue(), ^(xpc_object_t event) {
            xpc_type_t type = xpc_get_type(event);
            
            if (type == XPC_TYPE_ERROR) {
                
                if (event == XPC_ERROR_CONNECTION_INTERRUPTED) {
                    NSLog( @"XPC connection interupted." );
                } else if (event == XPC_ERROR_CONNECTION_INVALID) {
                    NSLog( @"XPC connection invalid, releasing." );
                    xpc_release(connection);
                    
                } else {
                    NSLog( @"Unexpected XPC connection error." );
                }
                
            } else {
                
                xpc_object_t reply = xpc_dictionary_create_reply(event);
                const char * replyString = xpc_dictionary_get_string( reply, "request" );
                
                if( strcmp( replyString, "STARTING" ) == 0 )
                {
                    //
                    //  OK IT IS STARTING
                    //  START RECEIVING THE OUTPUT LOG
                    //
                    
                    mustEndConnection = true;
                }
                
                if( strcmp( replyString, "FINISHING" ) == 0 )
                {
                    //
                    //  OK ITS FINISHING
                    //
                }
                
                NSLog( @"Unexpected XPC connection event." );
                mustEndConnection = true;
            }

        });
        
        xpc_connection_resume(connection);
    
        while( !mustEndConnection )
            ;
    }
    
    return kSUCCESS;
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
        case kVerifySheetIdentifier:    // run Verification
            
            arguments = [[NSArray alloc] initWithObjects:@"--verify", mountPoint, nil];     // ** TODO ** Should be --no-output ??
            
            break;
        case kRepairSheetIdentifier:    // run Repair
            break;
            
            arguments = [[NSArray alloc] initWithObjects:@"--repair", mountPoint, nil];     // ** TODO ** Should be --no-output ??
            
        default:
            NSLog( @"Unexpected sheetIdentifier passed! Aborting!" );                       //  ** TODO ** Handle error with some way. ---> This is nice I think.
            return;
            
            break;
    }
    
    if ( !_sheet )
        [[NSBundle bundleWithIdentifier:kEnhanceDiskUtilityBundleIdentifier] loadNibNamed:@"VerifyRepairPermissions" owner:self topLevelObjects:nil];
    
    [[NSApp mainWindow] beginSheet:self.sheet completionHandler:^(NSModalResponse returnCode) {
        didFinishRepairOrVerifyJob = YES;
    }];
    
    [_progressIndicator startAnimation:nil];
    
    //
    //  Start the process
    //
    
    [self executeUtilityWithArguments:arguments];
    
    [_progressIndicator stopAnimation:nil];
}

- (IBAction)closeSheet:(id)sender
{
    [[NSApp mainWindow] endSheet:self.sheet];       // ** TODO ** What is the proper way for closing it???
    //    [self.sheet close];
    self.sheet = nil;
}

- (BOOL)didFinishVerifying {
    return didFinishRepairOrVerifyJob;
}
- (BOOL)didFinishRepairing {
    return didFinishRepairOrVerifyJob;
}

@end

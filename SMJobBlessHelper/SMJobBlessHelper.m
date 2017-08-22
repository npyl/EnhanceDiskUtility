//
//  SMJobBlessHelper.m
//  EnhanceDiskUtility
//
//  Created by Nickolas Pylarinos on DONT_REALLY_REMEMBER.
//  Copyright © 2017 ulcheats. All rights reserved.
//

#include <syslog.h>
#include <xpc/xpc.h>

#import <Foundation/Foundation.h>



//
//  -- THESE ARE NOT NEEDED -- ** TODO ** Add function for cleaning up files in /Library/LaunchDaemons, PrivilegedHelpers,
//      see: https://stackoverflow.com/questions/24040765/communicate-with-another-app-using-xpc
//
//
//  ** TODO * Handle the events indicating error --> terminate the helper.
//
//  ** TODO ** I think we dont actually get any events because it is blocking till the task quits, fix this
//
//


static void __XPC_Peer_Event_Handler(xpc_connection_t connection, xpc_object_t event) {
    syslog(LOG_NOTICE, "Received event in helper.");

    // the utility
    NSTask * task = nil;
    
    
	xpc_type_t type = xpc_get_type(event);
    
	if (type == XPC_TYPE_ERROR) {
		if (event == XPC_ERROR_CONNECTION_INVALID) {
			// The client process on the other end of the connection has either
			// crashed or cancelled the connection. After receiving this error,
			// the connection is in an invalid state, and you do not need to
			// call xpc_connection_cancel(). Just tear down any associated state
			// here.
            NSLog(@"CONNECTION_INVALID");
		} else if (event == XPC_ERROR_TERMINATION_IMMINENT) {
			// Handle per-connection termination cleanup.
            NSLog(@"TERMINATION_IMMINENT");
        } else {
            NSLog( @"Got unexpected (and unsupported) XPC ERROR" );
        }

// if (task isrunning) kill
//        exit(EXIT_FAILURE);   ??
	} else {
        //
        //  Read EnhanceDiskUtility's given |mode| |mountPoint| and |RepairPermissionsUtilityPath|
        //

        NSLog( @"got START event" );

        
        xpc_connection_t connection = xpc_dictionary_get_remote_connection(event);
        
        const char * mode = xpc_dictionary_get_string( event, "mode" );
        const char * mountPoint = xpc_dictionary_get_string( event, "mountPoint" );
        const char * repairPermissionsUtilityPath = xpc_dictionary_get_string( event, "RepairPermissionsUtilityPath" );
        
        if (!mode || !mountPoint || !repairPermissionsUtilityPath )
            return;
        
        
        NSLog( @"mode = %s\nmntPoint = %s\nRepairPermissionsUtilityPath = %s", mode, mountPoint, repairPermissionsUtilityPath );
        
        //
        //  Inform client we got the information needed
        //
        xpc_object_t reply = xpc_dictionary_create_reply(event);
        xpc_dictionary_set_string( reply, "mode", "GOT_MODE" );
        xpc_dictionary_set_string( reply, "mountPoint", "GOT_MNTPOINT" );
        xpc_connection_send_message( connection, reply );
        
        
        //
        //  Start the Operation
        //
        xpc_object_t utilityData = xpc_dictionary_create(NULL, NULL, 0);
        
        task = [[NSTask alloc] init];
        [task setLaunchPath:[NSString stringWithUTF8String:repairPermissionsUtilityPath]];
        [task setArguments:@[ [NSString stringWithUTF8String:mode], [NSString stringWithUTF8String:mountPoint], @"--output", @"/tmp/RepairPermissionsUtility.log" ]];
        
        task.standardOutput = [NSPipe pipe];
        [[task.standardOutput fileHandleForReading] setReadabilityHandler:^(NSFileHandle *file) {
            NSData *data = [file availableData];                                                                // this will read to EOF, so call only once
            NSString * stringData = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            
            xpc_dictionary_set_string( utilityData, "utilityData", [stringData UTF8String] );
            xpc_connection_send_message( connection, utilityData );
            
            NSLog(@"Task output! %@", stringData );
        }];
        
        [task launch];
        [task waitUntilExit];

        //
        //  Notify EnhandeDiskUtility RepairPermissionsUtility finished
        //
        xpc_dictionary_set_string( utilityData, "utilityData", "FINISHED!" );
        xpc_connection_send_message( connection, utilityData );
        
        xpc_connection_cancel(connection);
        exit(EXIT_SUCCESS);
    }
}

static void __XPC_Connection_Handler(xpc_connection_t connection)  {
    syslog(LOG_NOTICE, "Configuring message event handler for helper.");
    
	xpc_connection_set_event_handler(connection, ^(xpc_object_t event) {
		__XPC_Peer_Event_Handler(connection, event);
	});
	
	xpc_connection_resume(connection);
}

int main(int argc, const char *argv[]) {
    
    xpc_connection_t service = xpc_connection_create_mach_service("org.npyl.EnhanceDiskUtility.SMJobBlessHelper",
                                                                  dispatch_get_main_queue(),
                                                                  XPC_CONNECTION_MACH_SERVICE_LISTENER);
    
    if (!service) {
        syslog(LOG_NOTICE, "Failed to create service.");
        exit(EXIT_FAILURE);
    }
    
    syslog(LOG_NOTICE, "Configuring connection event handler for helper");
    xpc_connection_set_event_handler(service, ^(xpc_object_t connection) {
        __XPC_Connection_Handler(connection);
    });
    
    xpc_connection_resume(service);
    
    dispatch_main();
    
    return EXIT_SUCCESS;        // ** TODO ** should this be EXIT_FAILURE ??? and xpc_main()???
}


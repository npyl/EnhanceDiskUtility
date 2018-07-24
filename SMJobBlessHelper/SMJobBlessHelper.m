//
//  SMJobBlessHelper.m
//  EnhanceDiskUtility
//
//  Created by Nickolas Pylarinos on DONT_REALLY_REMEMBER.
//  Copyright © 2017 ulcheats. All rights reserved.
//

#import <syslog.h>
#import <xpc/xpc.h>
#import <Foundation/Foundation.h>

#define SMJOBBLESSHELPER_IDENTIFIER "org.npyl.EnhanceDiskUtility.SMJobBlessHelper"

#ifdef DEBUG_MODE
#define DBG_LOG(str) syslog(LOG_NOTICE, str)
#else
#define DBG_LOG(str)
#endif

@interface SMJobBlessHelper : NSObject
{
    xpc_connection_t connection_handle;
    xpc_connection_t service;
}

- (instancetype)init;
- (void)dispatchMain;

@end

@implementation SMJobBlessHelper

- (void)receivedData:(NSNotification*)notif
{
    NSLog(@"DUE: SEND");
    
    NSFileHandle *fh = [notif object];
    NSData *data = [fh availableData];
    if (data.length > 0)
    {
        /* if data is found, re-register for more data (and print) */
        [fh waitForDataInBackgroundAndNotify];
        NSString *str = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        
        syslog(LOG_NOTICE, "Sending %s", [str UTF8String]);
        
        xpc_object_t msg = xpc_dictionary_create(NULL, NULL, 0);
        xpc_dictionary_set_string(msg, "utilityData", [str UTF8String]);
        xpc_connection_send_message(connection_handle, msg);
    }
};

- (void) __XPC_Peer_Event_Handler:(xpc_connection_t)connection withEvent:(xpc_object_t)event
{
    NSTask * task = nil;        /* the utility */
    
    xpc_type_t type = xpc_get_type(event);
    
    if (type == XPC_TYPE_ERROR) {
        if (event == XPC_ERROR_CONNECTION_INVALID) {
            // The client process on the other end of the connection has either
            // crashed or cancelled the connection. After receiving this error,
            // the connection is in an invalid state, and you do not need to
            // call xpc_connection_cancel(). Just tear down any associated state
            // here.
            syslog(LOG_NOTICE, "CONNECTION_INVALID");
        } else if (event == XPC_ERROR_TERMINATION_IMMINENT) {
            // Handle per-connection termination cleanup.
            syslog(LOG_NOTICE, "CONNECTION_IMMINENT");
        } else {
            syslog(LOG_NOTICE, "Got unexpected (and unsupported) XPC ERROR");
        }
        
        if (task && [task isRunning])     // TODO: this doesnt work???
            [task terminate];
        
        xpc_connection_cancel(connection);
        exit(EXIT_FAILURE);
    }
    else
    {
        connection_handle = connection;
        
        //
        //  Read EnhanceDiskUtility's given |mode| |mountPoint| and |RepairPermissionsUtilityPath|
        //
        const char * mode = xpc_dictionary_get_string(event, "mode");
        const char * mountPoint = xpc_dictionary_get_string(event, "mountPoint");
        const char * repairPermissionsUtilityPath = xpc_dictionary_get_string(event, "RepairPermissionsUtilityPath");
        
        if (!mode || !mountPoint || !repairPermissionsUtilityPath)
            exit(EXIT_FAILURE);
        
        NSLog(@"mode = %s\nmntPoint = %s\nRepairPermissionsUtilityPath = %s", mode, mountPoint, repairPermissionsUtilityPath);
        
        //
        //  Start the Operation
        //
        NSPipe *outputPipe = [[NSPipe alloc] init];
        NSPipe *errorPipe = [[NSPipe alloc] init];
        
        task = [[NSTask alloc] init];
        [task setLaunchPath:[NSString stringWithUTF8String:repairPermissionsUtilityPath]];
        [task setArguments:@[@"--no-output", [NSString stringWithUTF8String:mode], [NSString stringWithUTF8String:mountPoint]]];
        [task setStandardOutput:outputPipe];
        [task setStandardError:errorPipe];
        
        NSFileHandle *outputHandle = [outputPipe fileHandleForReading];
        NSFileHandle *errorHandle = [errorPipe fileHandleForReading];
        
        [outputHandle waitForDataInBackgroundAndNotify];
        [errorHandle waitForDataInBackgroundAndNotify];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(receivedData:) name:NSFileHandleDataAvailableNotification object:outputHandle];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(receivedData:) name:NSFileHandleDataAvailableNotification object:errorHandle];
        
        [task setTerminationHandler:^(NSTask *task) {
            
            //  NOTE: enable when using pipe
            // [task.standardOutput fileHandleForReading].readabilityHandler = nil;
            
            //
            //  Notify EnhandeDiskUtility RepairPermissionsUtility finished
            //
            xpc_object_t utilityData = xpc_dictionary_create(NULL, NULL, 0);
            xpc_dictionary_set_string(utilityData, "utilityData", "FINISHED!");
            xpc_dictionary_set_int64(utilityData, "terminationStatus", [task terminationStatus]);
            xpc_connection_send_message(connection, utilityData);
            
            xpc_connection_cancel(connection);
        }];
        
        [task launch];
        [task waitUntilExit];
    }
}

- (void) __XPC_Connection_Handler:(xpc_connection_t)connection
{
    xpc_connection_set_event_handler(connection, ^(xpc_object_t event)
                                     {
                                         [self __XPC_Peer_Event_Handler:connection withEvent:event];
                                     });
    
    xpc_connection_resume(connection);
}

- (void)dispatchMain
{
    dispatch_main();
}

- (instancetype)init
{
    self = [super init];
    if (self)
    {
        service = xpc_connection_create_mach_service(SMJOBBLESSHELPER_IDENTIFIER,
                                                     dispatch_get_main_queue(),
                                                     XPC_CONNECTION_MACH_SERVICE_LISTENER);
        if (!service)
        {
            syslog(LOG_NOTICE, "Failed to create service.");
            exit(EXIT_FAILURE);
        }
        
        xpc_connection_set_event_handler(service, ^(xpc_object_t connection)
                                         {
                                             [self __XPC_Connection_Handler:connection];
                                         });
        xpc_connection_resume(service);
    }
    return self;
}

@end

int main(int argc, const char *argv[])
{
    SMJobBlessHelper *helper = [[SMJobBlessHelper alloc] init];
    if (!helper)
        return EXIT_FAILURE;
    
    [helper dispatchMain];
    
    return EXIT_SUCCESS;
}


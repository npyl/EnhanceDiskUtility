//
//  main.m
//  runRepariPermissionsTool
//
//  Created by Nickolas Pylarinos on 27/06/2017.
//  Copyright © 2017 ulcheats. All rights reserved.
//

//
//
//

#import <Foundation/Foundation.h>
#import "STPrivilegedTask.h"


int main( void )
{
    NSError * myError = nil;
    
    NSPipe * pipe = [[NSPipe alloc] init];
    NSFileHandle * file = pipe.fileHandleForWriting;
    
    STPrivilegedTask * repairPermissionsTask = [[STPrivilegedTask alloc] init];
    
    [repairPermissionsTask setLaunchPath:@"/Users/develnpyl/RepairPermissions"];
    [repairPermissionsTask setArguments:@[ @"--output", @"/tmp/RepairPermissions.tmp", @"--verify", @"/" ] ];
    [repairPermissionsTask set]
    
    OSStatus err = [repairPermissionsTask launch];
    
    if (err != errAuthorizationSuccess) {
        if (err == errAuthorizationCanceled) {
            NSLog(@"User cancelled");
        } else {
            NSLog(@"Something went wrong");
        }
    } else {
        NSLog(@"Task successfully launched");
        
    }
    
    [repairPermissionsTask waitUntilExit];
    
    NSLog( @"Terminated with status: %i", [repairPermissionsTask terminationStatus] );
    NSLog( @"%@", [NSString stringWithContentsOfFile:@"/tmp/RepairPermissions.tmp" encoding:NSUTF8StringEncoding error:&myError ] );

    
    return 0;
}

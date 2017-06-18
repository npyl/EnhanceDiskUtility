//
//  main.m
//  EnhanceDiskUtility
//
//  Created by Nickolas Pylarinos on 16/06/2017.
//  Copyright © 2017 ulcheats. All rights reserved.
//

@import Foundation;
@import AppKit;

#import "ZKSwizzle.h"
#import "main.h"

bool gotSUWorkspaceViewControllerHandle = false;


@implementation DUEnhance : NSObject

- (IBAction)VerifyPermissions:(id)sender
{
    NSLog( @"Told to verify permissions" );
}
- (IBAction)RepairPermissions:(id)sender
{
    NSLog( @"Told to repair permissions!" );
    
    NSLog( @"Checking SIP status" );
}

- (void)revalidateToolbar           /* Overrides the default function present in DiskUtilty code. */
{
    NSLog( @"Got access to the SUToolbarController" );
    
    ZKOrig(void);
    
    if( !gotSUWorkspaceViewControllerHandle )
    {
        NSLog( @"First call: Must inject the buttons" );

        NSToolbar * toolbarHandle = ZKHookIvar( self, NSToolbar*, "_toolbar" );

        if( !toolbarHandle )
        {
            NSLog( @"DUEnhance HACK: Failed to get toolbarHandle" );
            
            /* **** TODO **** Handle error somehow */
            return;
        }

        /* Here we inject the buttons */
        
        gotSUWorkspaceViewControllerHandle = true;
    }
}

@end

@implementation CoreClass : NSObject

+ (void) load
{
    NSLog(@"EnhanceDiskUtility plugin installed");
    
    ZKSwizzle( DUEnhance, SUToolbarController );
}

@end

//
//  main.m
//  EnhanceDiskUtility
//
//  Created by Nickolas Pylarinos on 16/06/2017.
//  Copyright © 2017 ulcheats. All rights reserved.
//

//
//  For checking the SIP status got code from Piker Alpha's repo in github
//
//  THANK YOU VERY MUCH PIKER ALPHA
//
//  https://github.com/Piker-Alpha/csrstat/blob/master/csrstat.c
//

@import Foundation;
@import AppKit;

#import "main.h"
#import "ZKSwizzle.h"

bool gotSUWorkspaceViewControllerHandle = false;

//
//  SYSTEM INTEGRITY PROTECTION RELATED
//


typedef uint32_t csr_config_t;

/* Rootless configuration flags */
#define CSR_ALLOW_UNTRUSTED_KEXTS		(1 << 0)	// 1
#define CSR_ALLOW_UNRESTRICTED_FS		(1 << 1)	// 2
#define CSR_ALLOW_TASK_FOR_PID			(1 << 2)	// 4
#define CSR_ALLOW_KERNEL_DEBUGGER		(1 << 3)	// 8
#define CSR_ALLOW_APPLE_INTERNAL		(1 << 4)	// 16
#define CSR_ALLOW_UNRESTRICTED_DTRACE	(1 << 5)	// 32
#define CSR_ALLOW_UNRESTRICTED_NVRAM	(1 << 6)	// 64

#define CSR_VALID_FLAGS (CSR_ALLOW_UNTRUSTED_KEXTS | \
                            CSR_ALLOW_UNRESTRICTED_FS | \
                            CSR_ALLOW_TASK_FOR_PID | \
                            CSR_ALLOW_KERNEL_DEBUGGER | \
                            CSR_ALLOW_APPLE_INTERNAL | \
                            CSR_ALLOW_UNRESTRICTED_DTRACE | \
                            CSR_ALLOW_UNRESTRICTED_NVRAM)

/* Syscalls */
extern int csr_check(csr_config_t mask);
extern int csr_get_active_config(csr_config_t *config);

//==============================================================================

char * _csr_check(aMask, aFlipflag)
{
    bool stat = 0;
    
    // Syscall
    if (csr_check(aMask) != 0)
    {
        stat = (aFlipflag) ? 0 : 1;
    }
    else
    {
        stat = (aFlipflag) ? 1 : 0;
    }
    
    if (stat)
    {
        return("enabled");
    }
    
    return("\33[1mdisabled\33[0m");
}

@implementation DUEnhance : NSObject

- (IBAction)VerifyPermissions:(id)sender
{
    NSLog( @"Told to verify permissions" );
}

- (void)alertDidEnd:(NSAlert *)alert returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
}

- (IBAction)RepairPermissions:(id)sender
{
    NSLog( @"Told to repair permissions!" );
    
    NSLog( @"Checking SIP status" );
    
    uint32_t config = 0;
    
    csr_get_active_config(&config);
    
    //
    // Note: Apple is no longer using 0x67 but 0x77 for csrutil disabled!!!
    //
    
    if( strcmp( _csr_check(CSR_ALLOW_UNRESTRICTED_FS, 0), "disabled" ) != 0 )
    {
        NSWindow * windowHandle = ZKHookIvar( self, NSWindow*, "_attachedToWindow" );
        
        NSAlert *alert = [[[NSAlert alloc] init] autorelease];
        [alert addButtonWithTitle:@"OK"];
        [alert setMessageText:@"Failed to repair Permissions!"];
        [alert setInformativeText:@"System Integrity Protection is enabled! Please disable it!"];
        [alert setAlertStyle:NSAlertStyleCritical];
        
        [alert beginSheetModalForWindow:windowHandle completionHandler:^(NSModalResponse returnCode) {}];
        
        /* ** TODO ** does alert get autoreleased?? */
        
        return;
    }
    
    // if disabled run Permissions repair
    // if enabled stop, print alert and stop.
}

- (void)revalidateToolbar
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
        
        [self RepairPermissions:nil];
        
        gotSUWorkspaceViewControllerHandle = true;
    }
}

@end

@implementation CoreClass : NSObject

+ (void) load
{
    NSLog(@"DUEnhance plugin installed");
    
    ZKSwizzle( DUEnhance, SUToolbarController );
}

@end

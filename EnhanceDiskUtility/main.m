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

//
//  For verify / repair permissions I use FireWolf's utility
//
//  THANK YOU VERY MUCH FIREWOLF
//
//  https://www.firewolf.science/2016/07/repairpermissions-v3-now-supports-repairing-permissions-on-macos-sierra/
//

/*  TODO:
 *      1) replace NSLog with DUEnhanceLog ( which will be a function that will call NSLog only if Debug Mode is enabled. )
 *      2) fix a bug, that when we try to customise the toolbar, it doesnt show the original choices Disk Utility shows.
 *          PROBABLY need to add the other functions such as - (NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar*)toolbar
 *                                          - (NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar*)toolbar
 *                                          - (void)toolbarWillAddItem:(NSNotification *)notification
 *
 *              checkout http://cocoadevcentral.com/articles/000037.php
 */

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
    
    return("\33[1mdis    abled\33[0m");
}

NSString * const kNSToolbarVerifyPermissionsItemIdentifier = @"VerifyPermissionsItemIdentifier";
NSString * const kNSToolbarRepairPermissionsItemIdentifier = @"RepairPermissionsItemIdentifier";

@implementation DUEnhance : NSObject

- (void) taskFinished:(NSNotification *)note
{
    NSLog( @"Yeah it finished!" );
}

- (void)VerifyPermissions:(id)sender
{
    NSLog( @"Told to verify permissions" );
}

- (void)RepairPermissions:(id)sender
{
    NSLog( @"Told to repair permissions!" );
    
    NSLog( @"Checking SIP status" );
    
    uint32_t config = 0;
    
    csr_get_active_config(&config);
    
    //
    // Note: Apple is no longer using 0x67 but 0x77 for csrutil disabled!!!
    //
    
    if( strcmp( _csr_check(CSR_ALLOW_UNRESTRICTED_FS, 0), "enabled" ) == 0 )
    {
        NSWindow * windowHandle = ZKHookIvar( self, NSWindow*, "_attachedToWindow" );
        
        NSAlert *alert = [[[NSAlert alloc] init] autorelease];
        [alert addButtonWithTitle:@"OK"];
        [alert setMessageText:@"Warning! System Integrity Protection has enabled File System Protection!"];
        [alert setInformativeText:@"File System Protection ( as part of System Integrity Protection ) is enabled! Some permissions may not be repaired!"];
        [alert setAlertStyle:NSAlertStyleWarning];
        
        [alert beginSheetModalForWindow:windowHandle completionHandler:^(NSModalResponse returnCode) {}];
        
        /* ** TODO ** does alert get autoreleased?? */
    }
    
    // run wolf's repair permissions app.
}

- (NSToolbarItem *) toolbar:(NSToolbar *)toolbar
      itemForItemIdentifier:(NSString *)itemIdentifier
  willBeInsertedIntoToolbar:(BOOL)flag
{
    NSToolbarItem *toolbarItem = [[[NSToolbarItem alloc] initWithItemIdentifier: itemIdentifier] autorelease];
    
    if ([itemIdentifier isEqual: kNSToolbarVerifyPermissionsItemIdentifier]) {
        NSLog( @"Got REPPERM item identifier" );
        
        // Set the text label to be displayed in the
        // toolbar and customization palette
        
        [toolbarItem setLabel:@"Verify Permissions"];
        [toolbarItem setPaletteLabel:@"Verify Permissions"];
        
        // Set up a reasonable tooltip, and image
        // you will likely want to localize many of the item's properties
        
        
        
        //[toolbarItem setToolTip:@"Save Your Document"];       // ** TODO ** Investigate what this does.
        
        
        [toolbarItem setImage:[NSImage imageNamed:NSImageNameSmartBadgeTemplate]];
        
        // Tell the item what message to send when it is clicked
        [ toolbarItem setTarget:self ];
        [ toolbarItem setAction:@selector(VerifyPermissions:) ];
    } else if ([itemIdentifier isEqual: kNSToolbarRepairPermissionsItemIdentifier])  {
        NSLog( @"Got VERPERM item identifier" );
        
        // Set the text label to be displayed in the
        // toolbar and customization palette
        [toolbarItem setLabel:@"Repair Permissions"];
        [toolbarItem setPaletteLabel:@"Repair Permissions"];
        
        // Set up a reasonable tooltip, and image
        // you will likely want to localize many of the item's properties
        
        
        //[toolbarItem setToolTip:@"Save Your Document"];        // ** TODO ** Investigate what this does
        
        
        [toolbarItem setImage:[NSImage imageNamed:NSImageNameMenuOnStateTemplate]];
        
        // Tell the item what message to send when it is clicked
        [toolbarItem setTarget:self];
        [toolbarItem setAction:@selector(RepairPermissions:)];
    }
    else {
        // we need to call the default
        NSLog( @"Going for default" );
        
        // ** TODO ** FIXME
        // What do we need here so that this block is complete???
    }
    return toolbarItem;
}

- (void)revalidateToolbar
{
    NSLog( @"Got access to the SUToolbarController" );
    
    ZKOrig(void);   // ** TODO ** Check if this actually does work
    
    if( !gotSUWorkspaceViewControllerHandle )
    {
        NSLog( @"First call: Must inject the buttons" );

        NSToolbar * toolbarHandle = ZKHookIvar( self, NSToolbar*, "_toolbar" );

        gotSUWorkspaceViewControllerHandle = true;      // set the flag so that we dont ask again.
                                                        // if we find out later that getting the handle failed, we don't worry
                                                        //      Disk Utility will work without the Verify / Repair Permissions addon.
        
        if( !toolbarHandle )
        {
            NSLog( @"DUEnhance HACK: Failed to get toolbarHandle" );
            
            NSAlert *alert = [[[NSAlert alloc] init] autorelease];
            [alert addButtonWithTitle:@"OK"];
            [alert setMessageText:@"Failed to get toolbar handle!"];
            [alert setInformativeText:@"Disk Utility will work without the Verify/Repair Permissions addon"];
            [alert setAlertStyle:NSAlertStyleCritical];
            [alert runModal];
            

            return;                                     // break the code, DONT reach to [toolbar insert...blabla]
        }

        /* Here we inject the buttons */
        
        [toolbarHandle insertItemWithItemIdentifier:kNSToolbarVerifyPermissionsItemIdentifier atIndex:7];
        [toolbarHandle insertItemWithItemIdentifier:kNSToolbarRepairPermissionsItemIdentifier atIndex:8];
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

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
 *
 *
 *              checkout http://cocoadevcentral.com/articles/000037.php
 *
 *      3)  FIX a bug that, when we hit customise, and paste the default bar of items, the Verify / Repair Buttons disappear.
 *      4)  Check if ZKOrig functions actually work.
 *      ** TODO ** Check if this code works for cases when some are not visible
 *
 */

#import "main.h"
#import "ZKSwizzle.h"

#define DUE_DEBUG

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

void DUELog( NSString * str )
{
    #ifdef DUE_DEBUG
        NSLog( @"%@", str );
    #endif
}

@implementation DUEnhance : NSObject

- (void)VerifyPermissions:(id)sender
{
    DUELog( @"Told to verify permissions" );
}

- (void)RepairPermissions:(id)sender
{
    DUELog( @"Told to repair permissions!" );
    
    DUELog( @"Checking SIP status" );
    
    uint32_t config = 0;
    
    csr_get_active_config( &config );
    
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
        
        [alert beginSheetModalForWindow:windowHandle completionHandler:^(NSModalResponse returnCode) { } ];
    }
    
    // run wolf's repair permissions app.
    
}

- (NSToolbarItem *) toolbar:(NSToolbar *)toolbar
      itemForItemIdentifier:(NSString *)itemIdentifier
  willBeInsertedIntoToolbar:(BOOL)flag
{
    NSToolbarItem *toolbarItem = [[[NSToolbarItem alloc] initWithItemIdentifier: itemIdentifier] autorelease];
    
    if ( [itemIdentifier isEqual: kNSToolbarVerifyPermissionsItemIdentifier] ) {
        DUELog( @"Got REPPERM item identifier" );
        
        [toolbarItem setLabel:@"Verify Permissions"];
        [toolbarItem setPaletteLabel:@"Verify Permissions"];        // ** TODO ** what does this do?
        [toolbarItem setImage:[NSImage imageNamed:NSImageNameSmartBadgeTemplate]];
        [toolbarItem setTarget:self];
        [toolbarItem setAction:@selector(VerifyPermissions:)];
    
    } else if ( [itemIdentifier isEqual: kNSToolbarRepairPermissionsItemIdentifier] )  {
        DUELog( @"Got VERPERM item identifier" );
        
        [toolbarItem setLabel:@"Repair Permissions"];
        [toolbarItem setPaletteLabel:@"Repair Permissions"];    // ** TODO ** what does this do?
        [toolbarItem setImage:[NSImage imageNamed:NSImageNameMenuOnStateTemplate]];
        [toolbarItem setTarget:self];
        [toolbarItem setAction:@selector(RepairPermissions:)];
    }
    else {
        //
        //  we need to call the default implementation
        //
        
        toolbarItem = ZKOrig( NSToolbarItem*, toolbar, itemIdentifier, YES);                // ** TODO ** FIXME --- Guess its fixed.
                                                                                            // What do we need here so that this block is complete???
    }
    
    return toolbarItem;
}

- (void)revalidateToolbar
{
    DUELog( @"Got access to the SUToolbarController" );
    
    ZKOrig(void);
    
    if( !gotSUWorkspaceViewControllerHandle )
    {
        DUELog( @"First call: Must inject the buttons" );
        
        gotSUWorkspaceViewControllerHandle = true;      // set the flag so that we DONT run into this block again. ( the if-gotSUWorkspaceViewControllerHandle-block)
                                                        // if we find out later that getting the handle failed, we don't worry
                                                        //      Disk Utility will work without the Verify / Repair Permissions addon.


        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            
            NSToolbar * toolbarHandle = ZKHookIvar( self, NSToolbar*, "_toolbar" );
            
            if( !toolbarHandle )
            {
                DUELog( @"DUEnhance HACK: Failed to get toolbarHandle" );
                
                dispatch_async(dispatch_get_main_queue(), ^{

                    NSAlert *alert = [[[NSAlert alloc] init] autorelease];
                    [alert addButtonWithTitle:@"OK"];
                    [alert setMessageText:@"Failed to get toolbar handle!"];
                    [alert setInformativeText:@"Disk Utility will work without the Verify/Repair Permissions addon"];
                    [alert setAlertStyle:NSAlertStyleCritical];
                    [alert runModal];
                });
                
                
                return;                                     // break the code, DONT reach to [toolbar insert...blabla]
            }
            
            //
            // Here we inject the buttons
            //
            
            const NSUInteger itemsCount = [[toolbarHandle items] count];
            const NSUInteger verifyPermissionsItemIndex = itemsCount - 1;
            const NSUInteger repairPermissionsItemIndex = verifyPermissionsItemIndex + 1;
            
            dispatch_async(dispatch_get_main_queue(), ^{
                /* ** TODO ** Need to check for errors in inserting ?? */
                
                [toolbarHandle insertItemWithItemIdentifier:kNSToolbarVerifyPermissionsItemIdentifier atIndex:verifyPermissionsItemIndex];
                [toolbarHandle insertItemWithItemIdentifier:kNSToolbarRepairPermissionsItemIdentifier atIndex:repairPermissionsItemIndex];
            });
        });
    }
}

@end

@implementation CoreClass : NSObject

+ (void) load
{
    DUELog(@"DUEnhance plugin loading");
    
    ZKSwizzle( DUEnhance, SUToolbarController );
}

@end

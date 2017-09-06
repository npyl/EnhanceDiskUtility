//
//  main.m
//  EnhanceDiskUtility
//
//  Created by Nickolas Pylarinos on 16/06/2017.
//  Copyright © 2017 ulcheats. All rights reserved.
//
//  The Licenses reside inside the EnhanceDiskUtility.bundle!
//

//
//  THANK YOU VERY MUCH w0lfschild for helping me make the code better
//  His github: https://github.com/w0lfschild
//

//
//  This project uses the private framework StorageKit.framework ( located in /System/Library/PrivateFrameworks )
//  I used a utility to dump the class SKDisk and put it in a header file called StorageKit.h because I need it for the Verify / Repair
//      permissions functions.
//
//  ARC is disabled
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

//
//  For Executing FireWolf's Utility with root permissions I got help
//      from OCForks's project.  He actually updated the SMJobBless+XPC project
//      which was originally created by Nathan de Vries.
//
//  https://github.com/OCForks/SMJobBlessXPC
//  https://github.com/atnan/SMJobBlessXPC
//
//  Nathan de Vries post:
//  http://atnan.com/blog/2012/02/29/modern-privileged-helper-tools-using-smjobbless-plus-xpc/
//

/*  TODO:
 *
 *
 *              checkout http://cocoadevcentral.com/articles/000037.php
 *
 *      4)  Check if ZKOrig functions actually work.
 *      ** TODO ** Check if this code works for cases when some toolbar items are not visible
 *      ** TODO ** We need to deallocate the repair / verify toolbar item identifiers some time
 *      ** TODO ** There are actually more objects that need deallocation etc..
 *      ** TODO ** Enable ARC on all subprojects and this.
 */

#import "main.h"
#import "StorageKit.h"
#import "ZKSwizzle/ZKSwizzle.h"
#import "DUEVerifyRepairSheetController.h"


#define DUE_DEBUG

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

bool gotSUWorkspaceViewControllerHandle = false;

NSString * const kNSToolbarVerifyPermissionsItemIdentifier = @"VerifyPermissionsItemIdentifier";
NSString * const kNSToolbarRepairPermissionsItemIdentifier = @"RepairPermissionsItemIdentifier";

NSToolbarItem *verifyPermissionsItem = nil;
NSToolbarItem *repairPermissionsItem = nil;

SKDisk * globalSelectedDiskHandle = nil;

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
    
    NSString * mountPoint = ZKHookIvar( globalSelectedDiskHandle, NSString*, "_mountPoint" );
    
    DUEVerifyRepairSheetController * verifySheet = [[DUEVerifyRepairSheetController alloc] init];       // autoreleased internally
    [verifySheet showSheet:kVerifySheetIdentifier forMountPoint:mountPoint];
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
    
    NSString * mountPoint = ZKHookIvar( globalSelectedDiskHandle, NSString*, "_mountPoint" );
    
    DUEVerifyRepairSheetController * repairSheet = [[DUEVerifyRepairSheetController alloc] init];       // autoreleased internally
    [repairSheet showSheet:kRepairSheetIdentifier forMountPoint:mountPoint];
}

- (NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar*)toolbar      /* Overrides the default function */
{
    NSMutableArray * toolbarDefaultItemIdentifiers = [NSMutableArray arrayWithArray: ZKOrig( NSArray*, toolbar )];
    
    //
    //  Now patch a bit the array to add our buttons, too!
    //
    
    [toolbarDefaultItemIdentifiers setObject:kNSToolbarVerifyPermissionsItemIdentifier atIndexedSubscript:( [toolbarDefaultItemIdentifiers count] - 1 )];
    [toolbarDefaultItemIdentifiers addObject:kNSToolbarRepairPermissionsItemIdentifier];
    [toolbarDefaultItemIdentifiers addObject:NSToolbarFlexibleSpaceItemIdentifier];
    
    return toolbarDefaultItemIdentifiers;
}

- (NSToolbarItem *) toolbar:(NSToolbar *)toolbar
                        itemForItemIdentifier:(NSString *)itemIdentifier
                        willBeInsertedIntoToolbar:(BOOL)flag
{
    if ( [itemIdentifier isEqual: kNSToolbarVerifyPermissionsItemIdentifier] )
    {
        return verifyPermissionsItem;
    }
    else if ( [itemIdentifier isEqual: kNSToolbarRepairPermissionsItemIdentifier] )
    {
        return repairPermissionsItem;
    }
    else {
        //
        //  we need to call the default implementation
        //
        
        return ZKOrig( NSToolbarItem*, toolbar, itemIdentifier, YES);                       // ** TODO ** FIXME --- Guess its fixed.
                                                                                            // What do we need here so that this block is complete???
    }
}

- (void) createVerifyRepairPermissionsToolbarItems
{
    /* ** TODO ** Can have autorelease here?? 
        NO because when they get removed and then again put it crashes...
     */
    
    verifyPermissionsItem = [[NSToolbarItem alloc] initWithItemIdentifier: kNSToolbarVerifyPermissionsItemIdentifier];
    repairPermissionsItem = [[NSToolbarItem alloc] initWithItemIdentifier: kNSToolbarRepairPermissionsItemIdentifier];
    
    //
    // Use a NSButton to match the other Toolbar items in Disk Utility
    //
    
    NSButton *verifyPermissionsButton = [[NSButton alloc] initWithFrame:CGRectMake(0, 0, 42, 21)];
    [verifyPermissionsButton setBezelStyle:NSTexturedRoundedBezelStyle];
    [verifyPermissionsButton setButtonType:NSButtonTypeMomentaryPushIn];
    [verifyPermissionsButton setTarget:self];
    [verifyPermissionsButton setAction:@selector(VerifyPermissions:)];
    [verifyPermissionsButton setImage:[NSImage imageNamed:NSImageNameSmartBadgeTemplate]];
    [verifyPermissionsItem setLabel:@"Verify"];
    [verifyPermissionsItem setPaletteLabel:@"Verify"];
    [verifyPermissionsItem setView:verifyPermissionsButton];

    NSButton *repairPermissionsButton = [[NSButton alloc] initWithFrame:CGRectMake(0, 0, 42, 21)];
    [repairPermissionsButton setBezelStyle:NSTexturedRoundedBezelStyle];
    [repairPermissionsButton setButtonType:NSButtonTypeMomentaryPushIn];
    [repairPermissionsButton setTarget:self];
    [repairPermissionsButton setAction:@selector(RepairPermissions:)];
    [repairPermissionsButton setImage:[NSImage imageNamed:NSImageNameMenuOnStateTemplate]];
    [repairPermissionsItem setLabel:@"Repair"];
    [repairPermissionsItem setPaletteLabel:@"Repair"];
    [repairPermissionsItem setView:repairPermissionsButton];
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
                [self createVerifyRepairPermissionsToolbarItems];
                
                [toolbarHandle insertItemWithItemIdentifier:kNSToolbarVerifyPermissionsItemIdentifier atIndex:verifyPermissionsItemIndex];
                [toolbarHandle insertItemWithItemIdentifier:kNSToolbarRepairPermissionsItemIdentifier atIndex:repairPermissionsItemIndex];
            });
        });
    }
    
    //
    // Only show buttons as enabled if a device with a mount point is selected
    //
    
    if (globalSelectedDiskHandle) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.1 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            NSString *mountPoint = ZKHookIvar( globalSelectedDiskHandle, NSString*, "_mountPoint" );
            NSString *filesystem = ZKHookIvar( globalSelectedDiskHandle, NSString*, "_filesystemType" );
            
            if (mountPoint && ( [filesystem isEqualToString:kSKDiskFileSystemOSX] || [filesystem isEqualToString:kSKDiskFileSystemAPFS] ) ) {
                [verifyPermissionsItem setEnabled:true];
                [repairPermissionsItem setEnabled:true];
            } else {
                [verifyPermissionsItem setEnabled:false];
                [repairPermissionsItem setEnabled:false];
            }
        });
    }
}

@end

@implementation _due_SUWorkspaceViewController : NSViewController

- (void)viewDidLoad
{
    DUELog( @"Into current WorkspaceViewController" );
    DUELog( @"Getting current selectedDisk handle :)" );
    
    globalSelectedDiskHandle = ZKHookIvar( self, SKDisk*, "_disk" );
    
    ZKOrig(void);
}

@end

@implementation CoreClass : NSObject

+ (void) load
{
    DUELog(@"DUEnhance plugin loading");
    
    ZKSwizzle( _due_SUWorkspaceViewController, SUWorkspaceViewController );
    ZKSwizzle( DUEnhance, SUToolbarController );
}

@end

//
//  main.m
//  EnhanceDiskUtility
//
//  Created by Nickolas Pylarinos on 16/06/2017.
//  Copyright © 2017 ulcheats. All rights reserved.
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

/*  TODO:
 *
 *
 *              checkout http://cocoadevcentral.com/articles/000037.php
 *
 *      4)  Check if ZKOrig functions actually work.
 *      ** TODO ** Check if this code works for cases when some are not visible
 *      ** TODO ** We need to deallocate the repair / verify toolbar item identifiers some time
 *
 */

#import "main.h"
#import "StorageKit.h"
#import "ZKSwizzle/ZKSwizzle.h"

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


NSString * const kDUEStandardTempPath = @"/tmp/DUEnhance.tmp";

/* Called when there is some data in the output pipe */

-(void) receivedData:(NSNotification*)aNotification

{
    NSLog( @"receivedData!" );
    
    NSData *data = [[aNotification userInfo] objectForKey:NSFileHandleNotificationDataItem];
    
    // If the length of the data is zero, then the task is basically over - there is nothing
    // more to get from the handle so we may as well shut down.
    if ([data length])
    {
        // Send the data on to the controller; we can't just use +stringWithUTF8String: here
        // because -[data bytes] is not necessarily a properly terminated string.
        // -initWithData:encoding: on the other hand checks -[data length]
        //[controller appendOutput: [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease]];
        NSLog( @"%@", [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease] );
    } else {
        // We're finished here
        //[self stopProcess];
    }
    
    // we need to schedule the file handle go read more data in the background again.
    [[aNotification object] readInBackgroundAndNotify];
}

/* Called when there is some data in the error pipe */

-(void) receivedError:(NSNotification*) rec_not
{
    NSLog( @"Received Error Data" );

    NSData *dataOutput=[[rec_not userInfo] objectForKey:NSFileHandleNotificationDataItem];
    
    if( !dataOutput)
        
        NSLog(@">>>>>>>>>>>>>>Empty Data");
    
    [[rec_not object] readInBackgroundAndNotify];
    
    //[dataOutput release];
}

/* Called when the task is complete */

-(void) TaskCompletion:(NSNotification*) rec_not

{
    NSTask * task = [rec_not object];
    
    [task terminate];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NSFileHandleDataAvailableNotification object:[task standardOutput]];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NSFileHandleDataAvailableNotification object:[task standardError]];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NSTaskDidTerminateNotification object:task];

    NSLog( @"%d", [task terminationStatus] );
    
    [task release];
}

- (void) launchApplicationFromPath:(NSString *)launchPath
                     withArguments:(NSArray *)arguments
{
    NSPipe * outputpipe = [[[NSPipe alloc] init] autorelease];
    NSPipe * errorpipe = [[[NSPipe alloc] init] autorelease];

    NSFileHandle    *output = [outputpipe fileHandleForReading],
                    *error = [errorpipe fileHandleForReading];
    
    NSTask * task = [[[NSTask alloc] init] autorelease];
    
    [task setLaunchPath:launchPath];
    [task setArguments:arguments];
    [task setStandardOutput:outputpipe];
    [task setStandardError:errorpipe];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(receivedData:) name: NSFileHandleDataAvailableNotification object:output];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(receivedError:) name: NSFileHandleDataAvailableNotification object:error];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(TaskCompletion:) name: NSTaskDidTerminateNotification object:task];

    //[input writeData:[NSMutableData initWithString:@"test"]];
    [output readInBackgroundAndNotify];
    [error readInBackgroundAndNotify];
    
    [task launch];
}

- (void)VerifyPermissions:(id)sender
{
    DUELog( @"Told to verify permissions" );
    
    // ** TODO ** Need to lock the disk handle ???
    
    NSString * mountPoint = ZKHookIvar( globalSelectedDiskHandle, NSString*, "_mountPoint" );
    
    [self launchApplicationFromPath:@"/Users/develnpyl/repair_packages" withArguments:@[ @"--verify", @"--standard-pkgs", mountPoint ] ];
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
        
    [verifyPermissionsItem setLabel:@"Verify Permissions"];
    [verifyPermissionsItem setPaletteLabel:@"Verify Permissions"];        // ** TODO ** what does this do?
    [verifyPermissionsItem setImage:[NSImage imageNamed:NSImageNameSmartBadgeTemplate]];
    [verifyPermissionsItem setTarget:self];
    [verifyPermissionsItem setAction:@selector(VerifyPermissions:)];
    
    [repairPermissionsItem setLabel:@"Repair Permissions"];
    [repairPermissionsItem setPaletteLabel:@"Repair Permissions"];    // ** TODO ** what does this do?
    [repairPermissionsItem setImage:[NSImage imageNamed:NSImageNameMenuOnStateTemplate]];
    [repairPermissionsItem setTarget:self];
    [repairPermissionsItem setAction:@selector(RepairPermissions:)];
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

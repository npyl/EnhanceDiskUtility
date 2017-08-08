//
//  main.h
//  EnhanceDiskUtility
//
//  Created by Nickolas Pylarinos on 17/06/2017.
//  Copyright © 2017 ulcheats. All rights reserved.
//

#ifndef main_h
#define main_h

@import AppKit;


@interface DUEVerifyPermissionsSheetController : NSWindowController
{
    IBOutlet NSWindow * verifyPermissionsWindow;
}

@end
@interface DUERepairPermissionsSheetController : NSWindowController @end

@interface _due_SUWorkspaceViewController : NSViewController @end



@interface DUEnhance : NSObject         // ** TODO ** Change that with NSObject <NSToolbarDelegate> ????
{
    DUEVerifyPermissionsSheetController * verifyPermissionsSheet;
}

- (void)VerifyPermissions:(id)sender;
- (void)RepairPermissions:(id)sender;

//
//  for toolbar ------------------------------------------------------------------
//

- (NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar*)toolbar;

- (NSToolbarItem *)         toolbar:(NSToolbar *)toolbar
              itemForItemIdentifier:(NSString *)itemIdentifier
          willBeInsertedIntoToolbar:(BOOL)flag;

//
//  see apple's documentation on toolbars to understand
//  ------------------------------------------------------------------------------
//

- (void)createVerifyRepairPermissionsToolbarItems;

- (void)revalidateToolbar;                  // override

@end

@interface CoreClass : NSObject

+ (void) load;

@end

#endif /* main_h */

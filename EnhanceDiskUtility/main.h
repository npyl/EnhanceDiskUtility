//
//  main.h
//  EnhanceDiskUtility
//
//  Created by Nickolas Pylarinos on 17/06/2017.
//  Copyright © 2017 ulcheats. All rights reserved.
//

#ifndef main_h
#define main_h

@import Foundation;
@import Cocoa;
@import AppKit;

@interface DUEnhance : NSObject

- (IBAction)VerifyPermissions:(id)sender;
- (IBAction)RepairPermissions:(id)sender;

- (void)revalidateToolbar;           /* Overrides the default function present in DiskUtilty code
                                            by swizzling DUEnhance class into the SUToolbarController
                                      */

@end

@interface CoreClass : NSObject

+ (void) load;

@end

#endif /* main_h */

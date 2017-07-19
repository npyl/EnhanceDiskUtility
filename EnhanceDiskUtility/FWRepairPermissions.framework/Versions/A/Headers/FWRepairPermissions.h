//
//  FWRepairPermissions.h
//  FWRepairPermissions
//
//  Created by Nickolas Pylarinos on 28/06/2017.
//  Copyright © 2017 ulcheats. All rights reserved.
//

#import <Cocoa/Cocoa.h>

//! Project version number for FWRepairPermissions.
FOUNDATION_EXPORT double FWRepairPermissionsVersionNumber;

//! Project version string for FWRepairPermissions.
FOUNDATION_EXPORT const unsigned char FWRepairPermissionsVersionString[];

// In this header, you should import all the public headers of your framework using statements like #import <FWRepairPermissions/PublicHeader.h>


void        verifyPermissions( /* add a selector for NSFileHandleDataAvailiable handler here */ );
void        repairPermissions( /* add a selector for NSFileHandleDataAvailiable handler here */ );

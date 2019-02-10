//
//  main.m
//  SMJobBlessHelperCaller
//
//  Created by Nickolas Pylarinos on 04/08/2017.
//  Copyright © 2017 ulcheats. All rights reserved.
//

/*
 *  Dear surprised reader of this file,
 *
 *  I have added this SMJobBlessHelperCaller project because I want
 *      to be able to call the SMJobBlessHelper from EnhanceDiskUtility.bundle!
 *
 *  But, this cannot be done ( at this moment, anyway ) because the bundle gets
 *      loaded into DiskUtility application and then [NSBundle mainBundle] returns /Applications/Utilities/DiskUtility.app
 *      which means that the mainBundle is DiskUtility, not EnhanceDiskUtility.bundle!
 *
 *  Thus I can't run the helper because it doenst exist inside DiskUtility.app... Though, I can run a caller app
 *      which on its turn will call the Helper!
 *
 *  Also, this .app can be formless for less overhead! So we dont use the NSApplicationMain();
 *  For the same reason I have removed the storyboard file!!
 *
 *  -----------------------------------------------------------------------------------------------------------------------
 *
 *  How this works:
 *
 *  Asks user for password
 *  Runs the helper
 *  ( these are done inside blessHelperWithLabel() )
 *
 *  Exits and control is passed the EnhanceDiskUtility.bundle to do IPC with the helper
 *      and tell it to either do repair or verification of permissions!
 *
 *  ========================================================================================================================
 */

#import <Cocoa/Cocoa.h>
#import <ServiceManagement/ServiceManagement.h>

BOOL blessHelperWithLabel(NSString *label, NSError **error)
{
    BOOL result = NO;
    
    AuthorizationItem authItem		=   { kSMRightBlessPrivilegedHelper, 0, nil, 0 };
    AuthorizationRights authRights	=   { 1, &authItem };
    AuthorizationFlags flags		=	kAuthorizationFlagDefaults |
                                        kAuthorizationFlagInteractionAllowed |
                                        kAuthorizationFlagPreAuthorize |
                                        kAuthorizationFlagExtendRights;
    
    AuthorizationRef authRef = nil;
    CFErrorRef outError = nil;
    
    /* Obtain the right to install privileged helper tools (kSMRightBlessPrivilegedHelper). */
    OSStatus status = AuthorizationCreate(&authRights, kAuthorizationEmptyEnvironment, flags, &authRef);
    if (status != errAuthorizationSuccess) {
        NSLog(@"Failed to create AuthorizationRef. Error code: %d", (int)status);
        
    } else {
        /* This does all the work of verifying the helper tool against the application
         * and vice-versa. Once verification has passed, the embedded launchd.plist
         * is extracted and placed in /Library/LaunchDaemons and then loaded. The
         * executable is placed in /Library/PrivilegedHelperTools.
         */
        result = SMJobBless(kSMDomainSystemLaunchd, (CFStringRef)label, authRef, &outError);
        
        /* get NSError out of CFErrorRef */
        if (*error)
            *error = (__bridge NSError *)outError;
    }
    
    return result;
}

int main(int argc, const char * argv[]) {
    NSError *error = nil;
    
    if (!blessHelperWithLabel(@"org.npyl.EnhanceDiskUtility.SMJobBlessHelper", &error)) {
        NSLog(@"Failed to bless helper. Error: %@", error);
        return -1;
    }

    return 0;
}

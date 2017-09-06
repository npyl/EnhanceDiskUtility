//
//  StorageKit.h
//  EnhanceDiskUtility
//
//  This is NOT FROM APPLE, I used a utility to dump the SKDisk class
//
//  Created by Nickolas Pylarinos on 21/06/2017.
//  Copyright © 2017 ulcheats. All rights reserved.
//

#ifndef StorageKit_h
#define StorageKit_h

@import Foundation;

NSString    *kSKDiskFileSystemUndefined = @"kSKDiskFileSystemUndefined",
            *kSKDiskFileSystemOSX       = @"kSKDiskFileSystemOSX",
            *kSKDiskFileSystemFAT       = @"kSKDiskFileSystemFAT",
            *kSKDiskFileSystemExFAT     = @"kSKDiskFileSystemExFAT",
            *kSKDiskFileSystemNTFS      = @"kSKDiskFileSystemNTFS",
            *kSKDiskFileSystemACFS      = @"kSKDiskFileSystemACFS",
            *kSKDiskFileSystemAPFS      = @"kSKDiskFileSystemAPFS";

@interface SKDisk : NSObject
{
    NSArray *sortedChildren;
    NSObject *daDiskRef;
    BOOL isValid;
    BOOL canBeDeleted;
    BOOL isDiskImage;
    BOOL isSystemRAMDisk;
    BOOL isInternal;
    BOOL isSolidState;
    BOOL isWholeDisk;
    BOOL isPhysicalDisk;
    BOOL isWritable;
    BOOL supportsJournaling;
    BOOL isJournaled;
    BOOL isEjectable;
    BOOL isNetwork;
    BOOL isLocked;
    BOOL isOpticalDisc;
    BOOL canSupportRecoveryPartition;
    BOOL supportsRepair;
    BOOL supportsVerify;
    BOOL ownersEnabled;
    BOOL isCaseSensitive;
    BOOL partitionMapIsIncorrectlySized;
    int smartStatus;
    NSString *type;
    NSString *filesystemType;
    NSImage *diskIcon;
    NSString *volumeName;
    NSString *volumeUUID;
    NSString *mountPoint;
    unsigned long long freeSpace;
    unsigned long long purgeableSpace;
    unsigned long long availableSpace;
    unsigned long long totalSpace;
    unsigned long long minimumDiskSize;
    unsigned long long maximumDiskSize;
    NSString *diskIdentifier;
    NSString *protocol;
    NSString *mediaName;
    unsigned long long unformattedSize;
    unsigned long long childCount;
    unsigned long long startLocation;
    //SKFilesystem *filesystem;
    NSString *role;
}
@end

#endif /* StorageKit_h */

//
//  UIDevice+PLPL.m
//  Apollo
//
//  Created by xhan on 10-10-22.
//  Copyright 2010 Baidu.com. All rights reserved.
//

#import "UIDevice+PLPL.h"
#import "PLPLCore.h"

#include <sys/types.h>
#include <sys/sysctl.h>
#import <AdSupport/AdSupport.h>
#import "UIDevice+PLHardware.h"

@implementation UIDevice(PL)

- (BOOL)isPLIOS8AndAbove
{
    static int __isPLIOS8above = -1;
    if (__isPLIOS8above == -1) {
        __isPLIOS8above = (int)([[self systemVersion] floatValue]) >= 8;
    }
    return __isPLIOS8above ;
}

- (BOOL)isPLIOS9AndAbove
{
    static int __isPLIOS8above = -1;
    if (__isPLIOS8above == -1) {
        __isPLIOS8above = (int)([[self systemVersion] floatValue]) >= 9;
    }
    return __isPLIOS8above ;
}

- (BOOL)isPLIOS10AndAbove
{
    static int __isPLIOS8above = -1;
    if (__isPLIOS8above == -1) {
        __isPLIOS8above = (int)([[self systemVersion] floatValue]) >= 10;
    }
    return __isPLIOS8above ;
}

- (BOOL)isPLIOS11AndAbove
{
    static int __isPLIOS8above = -1;
    if (__isPLIOS8above == -1) {
        __isPLIOS8above = (int)([[self systemVersion] floatValue]) >= 11;
    }
    return __isPLIOS8above ;
}

- (long long)getTotalMemorySize
{
    return [NSProcessInfo processInfo].physicalMemory;
}

- (NSString *)platform
{
    return [self modelIdentifier];
}

UIDevice* PLPLMyDevice()
{
    return [UIDevice currentDevice];
}

@end



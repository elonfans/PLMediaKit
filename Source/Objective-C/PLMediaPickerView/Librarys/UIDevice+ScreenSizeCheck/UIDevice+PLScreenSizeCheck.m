//
//  UIDevice+PLScreenSizeCheck.m
//  QiuBai
//
//  Created by noark on 14/10/27.
//  Copyright (c) 2014年 Less Everything. All rights reserved.
//

#import "UIDevice+PLScreenSizeCheck.h"
#import "UIDevice+PLHardware.h"
#import "UIDevice+PLPL.h"

#if !__has_feature(objc_arc)
#error "enable ARC by add -fobjc-arc"
#endif

@implementation UIDevice (PLScreenSizeCheck)

+ (BOOL)isWideScreenIPhone
{
    BOOL ret = NO;
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
        CGSize screenSize = [UIScreen mainScreen].bounds.size;
        NSInteger height = screenSize.height;
        if (height >= 568) {
            ret = YES;
        }
    }
    return ret;
}

+ (BOOL)isiPhone6
{
    if ([@"iPhone7,2" isEqualToString:PLMyDevice().platform])
    {
        return YES;
    }
    return NO;
}

+ (BOOL)isiPhone6Plus
{
    if ([@"iPhone7,1" isEqualToString:PLMyDevice().platform])
    {
        return YES;
    }
    return NO;
}

@end

UIDevice *PLMyDevice()
{
    return [UIDevice currentDevice];
}

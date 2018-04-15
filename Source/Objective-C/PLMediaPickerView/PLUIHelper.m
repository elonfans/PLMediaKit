//
//  UIHelper.m
//  Demo
//
//  Created by Pauley Liu on 29/08/2017.
//  Copyright © 2017 Pauley Liu. All rights reserved.
//

#import "PLUIHelper.h"
#import "UIDevice+PLPL.h"

@implementation PLUIHelper

+ (UIFont *)fontWithSize:(CGFloat)size
{
    UIFont *font = [UIFont systemFontOfSize:size];
    if (PLPLMyDevice().isPLIOS9AndAbove) {
        font = [UIFont fontWithName:@"PingFangSC-Light" size:size];
    }
    return font;
}

@end

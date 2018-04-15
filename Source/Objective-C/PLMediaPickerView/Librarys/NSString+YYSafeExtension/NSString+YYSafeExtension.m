//
//  NSString+YYSafeExtension.m
//  Yeah
//
//  Created by Navi on 15/5/29.
//  Copyright (c) 2015年 QiuShiBaiKe. All rights reserved.
//

#import "NSString+YYSafeExtension.h"

@implementation NSString (YYSafeExtension)

- (NSString *)stringValue
{
    return self;
}

+ (BOOL)isNilOrNullForString:(NSString *)string
{
    if (!string || ![string isKindOfClass:[NSString class]] || string.length == 0) {
        return YES;
    }
    return NO;
}

+ (NSString *)readableStringForString:(NSString *)string
{
    if (!string) {
        return @"";
    } else if ([string isKindOfClass:[NSNull class]]) {
        return @"";
    } else if ([string isKindOfClass:[NSNumber class]]) {
        NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
        return [formatter stringFromNumber:(NSNumber *)string];
    } else if ([string isKindOfClass:[NSString class]]) {
        return string;
    } else {
        return @"";
    }
}

@end

//
//  NSString+YYSafeExtension.h
//  Yeah
//
//  Created by Navi on 15/5/29.
//  Copyright (c) 2015年 QiuShiBaiKe. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface NSString (YYSafeExtension)

- (NSString *)stringValue;

+ (BOOL)isNilOrNullForString:(NSString *)string;

/**
 *  @author ChenZheng, 15-07-14 09:07:18
 *
 *  @brief  将字符串的可能值（NSNull、nil、NULL、NSNumber等）转换成可以显示的字符串。不至于显示成"(null)"
 *
 *  @param string 待转换的字符串
 *
 *  @return 结果字符串
 */
+ (NSString *)readableStringForString:(NSString *)string;

@end
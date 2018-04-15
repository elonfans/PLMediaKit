//
//  NSString+Addition.h
//  Apollo
//
//  Created by xhan on 10-9-19.
//  Copyright 2010 ixHan.com. All rights reserved.
//

#import <Foundation/Foundation.h>

#define NSStringADD(_a_,_b_) [NSString stringWithFormat:@"%@%@",_a_,_b_]

@interface NSString(PLAddition)

@property(nonatomic,readonly)BOOL isEmpty;
@property(nonatomic,readonly)int countWithoutSpace;

//why has an isNonEmpty is it could easy to handle nil string object
// only the non-nil string with contents will return YES
- (BOOL)isNonEmpty;

//able to check nil object
+ (BOOL)isEqual:(NSString*)a toB:(NSString*)b;

// return examples:1.5 mb
+ (NSString*)localizedFileSize:(long long)fileSizeBytes;

// return the string starts from header and it's length not great than maxLength 
// 返回字符串开头长度为 maxLength 字符串
- (NSString*)firstString:(int)maxLength;

- (NSString*)firstString:(int)maxLength atIndex:(NSUInteger)index;

- (NSString *)md5;

- (NSString *)stripFreeLines;

- (NSString *)striped;

// 过滤掉 u200d 这个字符，会造成大小字问题
- (NSString *)stripU200dStr;

- (BOOL)contains:(NSString*)string;

@end


@interface NSString(XOR)

- (NSData*)xorWithKey:(NSString*)key;
+ (NSString*)xorFromData:(NSData*)data key:(NSString*)key;

//with base64 encoded
- (NSString*)xorEncodeWithKey:(NSString*)key;
- (NSString*)xorDecodeWithKey:(NSString*)key;

@end


@interface NSString (URLEscaped)

- (NSString *)URLEscaped;
- (NSString *)unURLEscape;

@end

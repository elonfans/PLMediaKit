//
//  NSDictionary+NonNull.m
//  Secret
//
//  Created by xu xhan on 7/5/11.
//  Copyright 2011 xu han. All rights reserved.
//

#import "NSDictionary+PLNonNull.h"

@implementation NSDictionary (NSDictionary_PLNonNull)
- (id)objectForKeyPL:(id)aKey
{
    id obj = self[aKey];
    if (obj == [NSNull null]) {
        return nil;
    }
    return obj;
}

- (int)intForKey:(id)aKey
{
    return [[self objectForKeyPL:aKey] intValue];
}

- (NSDictionary *)dictForKey:(NSString *)key
{
    if (key == nil) {
        return nil;
    }
    id dict = [self objectForKeyPL:key];
    if ([dict isKindOfClass:[NSDictionary class]]) {
        return dict;
    }
    return nil;
}

- (NSArray *)arrayForKey:(NSString *)key
{
    if (key == nil) {
        return nil;
    }
    id arr = [self objectForKeyPL:key];
    if ([arr isKindOfClass:[NSArray class]]) {
        return arr;
    }
    return nil;
}
- (NSString *)stringForKey:(NSString *)key
{
    if (key == nil) {
        return nil;
    }
    id str = [self objectForKeyPL:key];
    if ([str isKindOfClass:[NSString class]]) {
        return str;
    } else if (str) {
        return [NSString stringWithFormat:@"%@", str];
    }
    return nil;
}
- (NSNumber *)numberForKey:(NSString *)key
{
    if (key == nil) {
        return 0;
    }
    NSNumber *num = [self objectForKeyPL:key];
    if ([num isKindOfClass:[NSNumber class]]) {
        return num;
    }
    return nil;
}

- (NSInteger)integerForKey:(NSString *)key
{
    if (key == nil) {
        return 0;
    }
    return [[self objectForKeyPL:key] integerValue];
}
- (CGFloat)floatForKey:(NSString *)key
{
    if (key == nil) {
        return 0.0;
    }
    return [[self objectForKeyPL:key] floatValue];
}

- (double)doubleForKey:(NSString *)key
{
    if (key == nil) {
        return 0.0;
    }
    return [[self objectForKeyPL:key] doubleValue];
}

- (BOOL)boolForKey:(NSString *)key
{
    if (key == nil) {
        return 0.0;
    }
    return [[self objectForKeyPL:key] boolValue];
}

- (NSDate *)dateForKey:(NSString *)key
{
    if (key == nil) {
        return nil;
    }
    return [NSDate dateWithTimeIntervalSince1970:[self doubleForKey:key]];
}

@end

@implementation NSArray (NonNull)
- (id)objectAtIndexPL:(NSUInteger)index
{
    id obj = [self objectAtIndex:index];
    if (obj == [NSNull null]) {
        return nil;
    }
    return obj;
}
@end

//
//  NSDictionary+NonNull.h
//  Secret
//
//  Created by xu xhan on 7/5/11.
//  Copyright 2011 xu han. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface NSDictionary (NSDictionary_PLNonNull)

- (id)objectForKeyPL:(id)aKey;
- (int)intForKey:(id)aKey;

- (NSDictionary *)dictForKey:(NSString *)key;
- (NSArray *)arrayForKey:(NSString *)key;
- (NSString *)stringForKey:(NSString *)key;
- (NSNumber *)numberForKey:(NSString *)key;
- (NSInteger)integerForKey:(NSString *)key;
- (CGFloat)floatForKey:(NSString *)key;
- (double)doubleForKey:(NSString *)key;
- (BOOL)boolForKey:(NSString *)key;
- (NSDate *)dateForKey:(NSString *)key;

@end

@interface NSArray (PLNonNull)
- (id)objectAtIndexPL:(NSUInteger)index;
@end

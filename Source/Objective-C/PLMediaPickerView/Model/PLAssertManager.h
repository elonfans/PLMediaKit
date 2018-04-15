//
//  PLAssertManager.h
//  QiuBai
//
//  Created by 小飞 刘 on 5/24/16.
//  Copyright © 2016 Less Everything. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <Photos/Photos.h>
#import "PLMediaPickerViewController.h"

@interface PLAssertManager : NSObject

/**
 *  全部 Assert Groups
 */
@property (nonatomic, strong) NSArray *assertGroups;

/**
 *  全部 Assert 资源
 */
@property (nonatomic, strong) NSMutableArray *currentGroupAsserts;

/**
 *  获取全部 Assert Groups (已过滤资源数量为0的group)
 *
 *  @param block 回调全部Assert Groups
 */
- (void)assertGroupsForType:(PickerType)type block:(void (^)(NSArray *PLAssertGroupModelArray))block;

/**
 *  获取当前 Assert Group 的全部 Assert 资源
 *
 *  @param assertsGroup 资源组(如果为nil,按照默认组)
 *  @param block        回调当前组包含的全部Assert资源
 */
- (void)assertForType:(PickerType)type assertsGroup:(id)assertsGroup block:(void (^)(NSMutableArray *currentGroupAssertsArray))block;

/**
 *  获取 Assert
 *
 *  @param assert assert资源
 *  @param size   图片尺寸（传入CGSizeZero时获取最小尺寸缩略图）
 *  @param block  回调Image
 */
+ (void)assertImage:(id)assert size:(CGSize)size usingBlock:(void (^)(UIImage *image, BOOL isGif))block isNeedCompressed:(BOOL)isNeedCompressed;
+ (void)assertImage:(id)assert size:(CGSize)size usingDataBlock:(void (^)(NSData *imageData, BOOL isGif))block isNeedCompressed:(BOOL)isNeedCompressed;

/**
 *  判断是否同一个 Assert
 *
 *  @param assert     assert资源
 *  @param nextAssert 另外一个assert资源
 *
 *  @return YES / NO
 */
+ (BOOL)isEqulAssert:(id)assert nextAssert:(id)nextAssert;

@end

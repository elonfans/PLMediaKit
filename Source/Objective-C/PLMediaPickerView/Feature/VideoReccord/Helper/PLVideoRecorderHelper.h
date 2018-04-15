//
//  PLVideoRecorderHelper.h
//  QiuBai
//
//  Created by 小飞 刘 on 14/12/23.
//  Copyright (c) 2014年 Less Everything. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <QuartzCore/QuartzCore.h>

/**
 *  用途：视频功能工具类
 */

@interface PLVideoRecorderHelper : NSObject

// videoRecorder
+ (CGFloat)getFileSize:(NSURL *)fileURL;
+ (NSString *)getFilePathByTime;
+ (NSString *)getMovFilePathByTime;
+ (NSTimeInterval)getVideoDuration:(NSURL *)fileURL;
+ (BOOL)saveToAppDocumentWithFileURL:(NSURL *)fileURL;
+ (BOOL)onlyShowForTheFirstTimeForKey:(NSString *)key;

// videoHandle
+ (NSString *)convertTime:(CGFloat)second;

// 添加片尾
+ (void)addVideoTail:(AVMutableVideoComposition *)mainCompositionInst lastImage:(UIImage *)lastImage totalDuration:(CMTime)totalDuration;

@end

//
//  HKMediaRecorderTools.h
//  YeahMV
//
//  Created by HuangKai on 15/11/5.
//  Copyright © 2015年 QiuShiBaiKe. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
@interface PLHKMediaRecorderTools : NSObject
+ (NSString  *__nonnull)AVCaptureSessionPresetConfigByMachineModel;
+ (CGSize )videoSizeConfigByMachineModel;
+ (BOOL)formatInRange:(AVCaptureDeviceFormat *__nonnull)format frameRate:(CMTimeScale)frameRate;

+ (BOOL)formatInRange:(AVCaptureDeviceFormat *__nonnull)format frameRate:(CMTimeScale)frameRate dimensions:(CMVideoDimensions)videoDimensions;

+ (CMTimeScale)maxFrameRateForFormat:(AVCaptureDeviceFormat *__nonnull)format minFrameRate:(CMTimeScale)minFrameRate;
+ (BOOL)is_iPhone4Device;
@end

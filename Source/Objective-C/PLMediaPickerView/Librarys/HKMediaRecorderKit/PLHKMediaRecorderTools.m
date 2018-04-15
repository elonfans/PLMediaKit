//
//  HKMediaRecorderTools.m
//  YeahMV
//
//  Created by HuangKai on 15/11/5.
//  Copyright © 2015年 QiuShiBaiKe. All rights reserved.
//

#import "PLHKMediaRecorderTools.h"
#import <sys/utsname.h>

@implementation PLHKMediaRecorderTools

+ (NSString *)AVCaptureSessionPresetConfigByMachineModel
{
    struct utsname systemInfo;
    uname(&systemInfo);
    NSString *deviceString = [NSString stringWithCString:systemInfo.machine encoding:NSUTF8StringEncoding];
    
    if ([deviceString isEqualToString:@"iPhone1,1"])    return AVCaptureSessionPresetHigh;
    if ([deviceString isEqualToString:@"iPhone1,2"])    return AVCaptureSessionPresetHigh;
    if ([deviceString isEqualToString:@"iPhone2,1"])    return AVCaptureSessionPresetHigh;
    if ([deviceString isEqualToString:@"iPhone3,1"])    return AVCaptureSessionPreset640x480;
    if ([deviceString isEqualToString:@"iPhone3,2"])    return AVCaptureSessionPreset640x480;//4
    if ([deviceString isEqualToString:@"iPhone4,1"])    return AVCaptureSessionPreset640x480;//4s
    if ([deviceString isEqualToString:@"iPhone5,2"])    return AVCaptureSessionPresetiFrame960x540;//5s
    if ([deviceString isEqualToString:@"iPhone6,2"])    return AVCaptureSessionPresetiFrame960x540;//5s
    if ([deviceString isEqualToString:@"iPhone7,2"])    return AVCaptureSessionPresetiFrame960x540;//6
    if ([deviceString isEqualToString:@"iPhone7,1"])    return AVCaptureSessionPresetiFrame960x540;//6p
    if ([deviceString isEqualToString:@"iPhone8,1"])    return AVCaptureSessionPresetiFrame960x540;//6s
    if ([deviceString isEqualToString:@"iPhone8,2"])    return AVCaptureSessionPresetiFrame960x540;//6sp
    if ([deviceString isEqualToString:@"iPod1,1"])      return AVCaptureSessionPresetHigh;
    if ([deviceString isEqualToString:@"iPod2,1"])      return AVCaptureSessionPresetHigh;
    if ([deviceString isEqualToString:@"iPod3,1"])      return AVCaptureSessionPresetHigh;
    if ([deviceString isEqualToString:@"iPod4,1"])      return AVCaptureSessionPresetHigh;
    if ([deviceString isEqualToString:@"iPad1,1"])      return AVCaptureSessionPresetHigh;
    if ([deviceString isEqualToString:@"iPad2,1"])      return AVCaptureSessionPresetHigh;
    if ([deviceString isEqualToString:@"iPad2,2"])      return AVCaptureSessionPresetHigh;
    if ([deviceString isEqualToString:@"iPad2,3"])      return AVCaptureSessionPresetHigh;
    if ([deviceString isEqualToString:@"iPad3,4"])      return AVCaptureSessionPresetHigh;
    if ([deviceString isEqualToString:@"i386"])         return AVCaptureSessionPresetHigh;
    if ([deviceString isEqualToString:@"x86_64"])       return AVCaptureSessionPresetHigh;
    
    return AVCaptureSessionPresetiFrame960x540;
}

+ (BOOL)is_iPhone4Device
{
    struct utsname systemInfo;
    uname(&systemInfo);
    NSString *deviceString = [NSString stringWithCString:systemInfo.machine encoding:NSUTF8StringEncoding];
    return [deviceString isEqualToString:@"iPhone3,2"] || [deviceString isEqualToString:@"iPhone3,1"];
}

+ (CGSize)videoSizeConfigByMachineModel{
    return CGSizeMake(480, 480);
}
+ (BOOL)formatInRange:(AVCaptureDeviceFormat*)format frameRate:(CMTimeScale)frameRate {
    CMVideoDimensions dimensions;
    dimensions.width = 0;
    dimensions.height = 0;
    
    return [PLHKMediaRecorderTools formatInRange:format frameRate:frameRate dimensions:dimensions];
}

+ (BOOL)formatInRange:(AVCaptureDeviceFormat*)format frameRate:(CMTimeScale)frameRate dimensions:(CMVideoDimensions)dimensions {
    CMVideoDimensions size = CMVideoFormatDescriptionGetDimensions(format.formatDescription);
    
    if (size.width >= dimensions.width && size.height >= dimensions.height) {
        for (AVFrameRateRange *range in format.videoSupportedFrameRateRanges) {
            if (range.minFrameDuration.timescale >= frameRate && range.maxFrameDuration.timescale <= frameRate) {
                return YES;
            }
        }
    }
    
    return NO;
}

+ (CMTimeScale)maxFrameRateForFormat:(AVCaptureDeviceFormat *)format minFrameRate:(CMTimeScale)minFrameRate {
    CMTimeScale lowerTimeScale = 0;
    for (AVFrameRateRange *range in format.videoSupportedFrameRateRanges) {
        if (range.minFrameDuration.timescale >= minFrameRate && (lowerTimeScale == 0 || range.minFrameDuration.timescale < lowerTimeScale)) {
            lowerTimeScale = range.minFrameDuration.timescale;
        }
    }
    
    return lowerTimeScale;
}
@end

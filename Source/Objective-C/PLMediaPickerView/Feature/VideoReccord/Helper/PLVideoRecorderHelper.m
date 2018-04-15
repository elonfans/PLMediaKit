//
//  PLVideoRecorderHelper.m
//  QiuBai
//
//  Created by 小飞 刘 on 14/12/23.
//  Copyright (c) 2014年 Less Everything. All rights reserved.
//

#import "PLVideoRecorderHelper.h"
#import <Accelerate/Accelerate.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreImage/CoreImage.h>
#import <UIKit/UIKit.h>

@implementation PLVideoRecorderHelper

+ (CVPixelBufferRef)pixelBufferFromCGImage:(CGImageRef)image size:(CGSize)size
{
    NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:
                                              [NSNumber numberWithBool:YES], kCVPixelBufferCGImageCompatibilityKey, [NSNumber numberWithBool:YES], kCVPixelBufferCGBitmapContextCompatibilityKey, nil];
    CVPixelBufferRef pxbuffer = NULL;
    CVReturn status = CVPixelBufferCreate(kCFAllocatorDefault, size.width, size.height, kCVPixelFormatType_32ARGB, (__bridge CFDictionaryRef) options, &pxbuffer);

    NSParameterAssert(status == kCVReturnSuccess && pxbuffer != NULL);

    CVPixelBufferLockBaseAddress(pxbuffer, 0);
    void *pxdata = CVPixelBufferGetBaseAddress(pxbuffer);
    NSParameterAssert(pxdata != NULL);

    CGColorSpaceRef rgbColorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(pxdata, size.width, size.height, 8, 4 * size.width, rgbColorSpace, kCGImageAlphaPremultipliedFirst);
    NSParameterAssert(context);

    CGContextDrawImage(context, CGRectMake(0, 0, CGImageGetWidth(image), CGImageGetHeight(image)), image);

    CGColorSpaceRelease(rgbColorSpace);
    CGContextRelease(context);

    CVPixelBufferUnlockBaseAddress(pxbuffer, 0);

    return pxbuffer;
}

// 获取文件大小
+ (CGFloat)getFileSize:(NSURL *)fileURL
{
    NSNumber *fileSizeBytes;
    NSError *error;
    NSURL *samplePath = [[NSURL alloc] initWithString:[fileURL absoluteString]];
    [samplePath getResourceValue:&fileSizeBytes forKey:NSURLFileSizeKey error:&error];
    if (error) {
        NSLog(@"error:%@", error);
        return 0;
    } else {
        CGFloat fileSize = [fileSizeBytes floatValue] / (1024); // convert to KB
        return fileSize;
    }
}

// 获取文件路径
+ (NSString *)getFilePathByTime
{
    NSString *path = [NSHomeDirectory() stringByAppendingPathComponent:@"Documents"];
    NSString *subPath = @"PLMediaPickerResource";
    path = [path stringByAppendingPathComponent:subPath];
    
    if (![[NSFileManager defaultManager] fileExistsAtPath:path]) {
        BOOL success = [[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];
        if (!success) {
            NSLog(@"目录创建失败");
        }
    }
    
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"yyyyMMddHHmmss";
    NSString *nowTimeStr = [formatter stringFromDate:[NSDate dateWithTimeIntervalSinceNow:0]];
    NSString *fileName = [[subPath stringByAppendingPathComponent:nowTimeStr] stringByAppendingString:@".mp4"];
    return fileName;
}

// 根据时间创建视频名称
+ (NSString *)getMovFilePathByTime
{
    NSString *path = NSTemporaryDirectory();
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"yyyyMMddHHmmss";
    NSString *nowTimeStr = [formatter stringFromDate:[NSDate dateWithTimeIntervalSinceNow:0]];
    NSString *fileName = [[path stringByAppendingPathComponent:nowTimeStr] stringByAppendingString:@".MOV"];
    return fileName;
}

// 获取视频时长
+ (NSTimeInterval)getVideoDuration:(NSURL *)fileURL
{
    NSURL *url = fileURL;
    AVURLAsset *assert = [[AVURLAsset alloc] initWithURL:url options:nil];
    NSTimeInterval durationInSeconds = 0.0f;
    if (assert) {
        durationInSeconds = CMTimeGetSeconds(assert.duration);
    }
    return durationInSeconds;
}

// 保存视频文件到指定路径
+ (BOOL)saveToAppDocumentWithFileURL:(NSURL *)fileURL
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    BOOL isSaveToAppDocumentSuccess;
    if ([fileManager fileExistsAtPath:[fileURL absoluteString]]) {
        NSData *data = [NSData dataWithContentsOfFile:[fileURL absoluteString]];
        isSaveToAppDocumentSuccess = [data writeToURL:fileURL atomically:YES];
    } else {
        isSaveToAppDocumentSuccess = NO;
        NSLog(@"file is not exist:%@", fileURL);
    }
    return isSaveToAppDocumentSuccess;
}

// 是否第一次展示
+ (BOOL)onlyShowForTheFirstTimeForKey:(NSString *)key
{
    if (![[NSUserDefaults standardUserDefaults] boolForKey:key]) {
        NSUserDefaults *userDefault = [NSUserDefaults standardUserDefaults];
        [userDefault setBool:YES forKey:key];
        [userDefault synchronize];
        return YES;
    } else {
        return NO;
    }
    return NO;
}

// 时间格式转换
+ (NSString *)convertTime:(CGFloat)second
{
    NSDate *d = [NSDate dateWithTimeIntervalSince1970:second];
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    if (second / 3600 >= 1) {
        [formatter setDateFormat:@"HH:mm:ss"];
    } else {
        [formatter setDateFormat:@"mm:ss"];
    }
    NSString *showtimeNew = [formatter stringFromDate:d];
    return showtimeNew;
}

+ (void)addVideoTail:(AVMutableVideoComposition *)mainCompositionInst lastImage:(UIImage *)lastImage totalDuration:(CMTime)totalDuration;
{
    CALayer *lastBgLayer = [CALayer layer];
    lastBgLayer.contentsGravity = kCAGravityResizeAspectFill;
    lastBgLayer.frame = CGRectMake(0, 0, mainCompositionInst.renderSize.width, mainCompositionInst.renderSize.height);
    [lastBgLayer setContents:(id) lastImage.CGImage];
    lastBgLayer.opacity = 0.0f;
    CABasicAnimation *transformAnima1 = [CABasicAnimation animationWithKeyPath:@"opacity"];
    transformAnima1.duration = 2;
    [transformAnima1 setRemovedOnCompletion:NO];
    [transformAnima1 setFillMode:kCAFillModeForwards];
    transformAnima1.fromValue = @(1.0f);
    transformAnima1.toValue = @(1.0f);
    transformAnima1.beginTime = CMTimeGetSeconds(totalDuration) - 2.0f; //CACurrentMediaTime() +
    [lastBgLayer addAnimation:transformAnima1 forKey:@"A"];

    CALayer *exportWatermarkLayer = [CALayer layer];
    [exportWatermarkLayer setContents:(id)[[UIImage imageNamed:@"resource.bundle/videoWaterMask@3x.png"] CGImage]];
    exportWatermarkLayer.opacity = 0.0f;
    CABasicAnimation *transformAnima = [CABasicAnimation animationWithKeyPath:@"opacity"];
    transformAnima.duration = 2;
    [transformAnima setRemovedOnCompletion:NO];
    [transformAnima setFillMode:kCAFillModeForwards];
    transformAnima.fromValue = @(0.0f);
    transformAnima.toValue = @(1.0f);
    transformAnima.beginTime = CMTimeGetSeconds(totalDuration) - 2.0f; //CACurrentMediaTime() +
    [exportWatermarkLayer addAnimation:transformAnima forKey:@"B"];

    CALayer *parentLayer = [CALayer layer];
    CALayer *videoLayer = [CALayer layer];
    parentLayer.frame = CGRectMake(0, 0, mainCompositionInst.renderSize.width, mainCompositionInst.renderSize.height);
    videoLayer.frame = parentLayer.bounds;
    exportWatermarkLayer.frame = CGRectMake((mainCompositionInst.renderSize.width - 91 * 2) / 2.0f, (mainCompositionInst.renderSize.height - 33 * 2) / 2.0f, 91 * 2, 33 * 2);
    [parentLayer addSublayer:videoLayer];
    [parentLayer addSublayer:lastBgLayer];
    [parentLayer addSublayer:exportWatermarkLayer];
    mainCompositionInst.animationTool = [AVVideoCompositionCoreAnimationTool videoCompositionCoreAnimationToolWithPostProcessingAsVideoLayer:videoLayer inLayer:parentLayer];
}

@end

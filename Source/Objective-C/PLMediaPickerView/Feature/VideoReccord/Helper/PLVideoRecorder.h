//
//  PLVideoRecorder.h
//  QiuBai
//
//  Created by 小飞 刘 on 14/12/23.
//  Copyright (c) 2014年 Less Everything. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <MediaPlayer/MediaPlayer.h>
#import "PLSDAVAssetExportSession.h"

#define COUNT_DUR_TIMER_INTERVAL 0.1

/**
 *  用途：视频拍摄功能封装
 */

typedef NS_ENUM(NSUInteger, VideoRecoderState) {
    VideoRecoderStateInit = 1,              // 初始化
    VideoRecoderStateReadyToRecord,     // 随时准备拍摄，。。。写文件
    VideoRecoderStateRecording,         // 拍摄中，。。。写文件
};

@class PLVideoRecorder;

@protocol PLVideoRecorderDelegate <NSObject>
@optional
- (void)PLVideoRecorder:(PLVideoRecorder*)PLVideoRecorder didStartRecordingToOutPutFileAtURL:(NSURL*)fileURL;
- (void)PLVideoRecorder:(PLVideoRecorder*)PLVideoRecorder didRecordingToOutPutFileAtURL:(NSURL*)outputFileURL duration:(CGFloat)videoDuration;
- (void)PLVideoRecorder:(PLVideoRecorder *)PLVideoRecorder didFinishRecordingToOutPutFileAtURL:(NSURL *)outputFileURL duration:(CGFloat)videoDuration error:(NSError*)error;
@end


@interface PLVideoRecorder : NSObject<AVCaptureFileOutputRecordingDelegate>

@property (nonatomic,weak) id <PLVideoRecorderDelegate>delegate;
@property (nonatomic,strong) AVCaptureSession *captureSession;
@property (nonatomic,strong) AVCaptureMovieFileOutput *movieFileOutput;
@property (nonatomic,strong) AVCaptureVideoPreviewLayer *videoPreview;
@property (nonatomic, readonly) VideoRecoderState state;

// Device
- (void)initCaptureDevice;
- (BOOL)isCameraSupported;
- (BOOL)isFrontCameraSupported;
- (BOOL)isUsingFrontCamera;
- (BOOL)isTorchOn;
- (BOOL)isTorchSupported;

// Actions
- (void)openTorch:(BOOL)open;
- (void)switchCamera;
- (CGFloat)getVideoDuration; // recorded time
- (void)startRecordingOutputFile;
- (void)stopCurrentVideoRecording;
- (void)subjectAreaDidChange;
- (void)focusAndExposeTap:(CGPoint)tapPoint;

@end


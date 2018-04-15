//
//  HKMediaRecorder.h
//  HKMediaRecorderKit
//
//  Created by HuangKai on 15/10/30.
//  Copyright © 2015年 KayWong. All rights reserved.
//
@import UIKit;
#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import "PLHKPreviewView.h"
#import "PLHKMediaRecorderDelegate.h"

typedef NS_ENUM( NSInteger, HKCamSetupResult ) {
    HKCamSetupResultSuccess,
    HKCamSetupResultCameraNotAuthorized,
    HKCamSetupResultSessionConfigurationFailed
};

typedef NS_ENUM( NSInteger, HKRecordMode ) {
    HKRecordModeAuto,
    HKRecordModeNight,
};

@interface PLHKMediaRecorder : NSObject <AVCaptureFileOutputRecordingDelegate , AVCaptureVideoDataOutputSampleBufferDelegate>

@property (nonatomic , weak) id <PLHKMediaRecorderDelegate>delegate;
@property (nonatomic , strong) NSMutableArray *segments;
@property (nonatomic , strong) NSMutableArray *segmentsCamaraPositionArray;
@property (nonatomic , strong) AVAsset *assetRepresentingSegments;
@property (nonatomic , strong) PLHKPreviewView *previewView;
// Session management.

@property (nonatomic) dispatch_queue_t sessionQueue;
@property (nonatomic) AVCaptureSession *session;
@property (nonatomic) AVCaptureDeviceInput *videoDeviceInput;
@property (nonatomic) AVCaptureMovieFileOutput *movieFileOutput;
@property (nonatomic , strong) AVCaptureVideoDataOutput *videoDataOutput;
@property (nonatomic , strong) AVCaptureDevice *videoDevice;


@property (nonatomic) AVCaptureStillImageOutput *stillImageOutput;
@property (nonatomic) HKCamSetupResult setupResult;
@property (nonatomic) HKRecordMode recordMode;
@property (nonatomic, getter=isSessionRunning) BOOL sessionRunning;
@property (nonatomic) UIBackgroundTaskIdentifier backgroundRecordingID;

@property (nonatomic , assign ,readonly) BOOL isRecording;
@property (nonatomic , assign ,readonly) CGFloat float_totalDur;
@property (nonatomic , assign ,readonly) CGFloat float_currentDur;
@property (nonatomic , assign ,readonly) CGFloat currentTimeScale;

@property (nonatomic , assign) BOOL isPreparingToExportRecording;

@property (nonatomic, readonly) BOOL isTorchSupported;
@property (nonatomic) BOOL isTorchOn;
@property (nonatomic) BOOL isUsingFrontCamera;

- (void)startRunning;
- (void)startRecording;
- (void)pause;
- (void)stopRecording;
- (void)stopRunning;
- (void)setVideoTimeScale:(CGFloat)timeScale;
- (void)switchCamara;
- (void)removeObservers;
- (void)removeAllSegments;
- (void)resetRescordSession;
- (void)deleteCurrentAsset;
- (void)beginExportMergedSegmentAsset;

- (void)mergeSegmsWithFileURLs:(NSArray *)fileURLArray;
- (void)focusAndExposeTap:(UIGestureRecognizer *)gestureRecognizer;

- (void)setRecordMode:(HKRecordMode)recordMode;
- (void)openNightMode;
- (void)closeNightMode;
- (BOOL)isReadyToRecord;

@end

//
//  HKMediaRecorderDelegate.h
//  HKMediaRecorderKit
//
//  Created by HuangKai on 15/11/2.
//  Copyright © 2015年 KayWong. All rights reserved.
//
#import <Foundation/Foundation.h>

@class PLHKMediaRecorder;

@protocol PLHKMediaRecorderDelegate <NSObject>

- (void)recorder:(PLHKMediaRecorder *)recorder didFinishSwitchCamara:(AVCaptureDevicePosition)captureDevicePosition;
- (void)recorder:(PLHKMediaRecorder *)recorder didStartRecordingToOutputFileAtURL:(NSURL *)fileURL;
- (void)recorder:(PLHKMediaRecorder *)recorder didFinishRecordingToOutputFileAtURL:(NSURL *)outputFileURL;
- (void)recorder:(PLHKMediaRecorder *)recorder didRecordedDuration:(CGFloat)duration totalDuration:(CGFloat)totalDuration;
- (void)recorder:(PLHKMediaRecorder *)recorder didFailedConfigSegments:(NSError *)error;
- (void)recorder:(PLHKMediaRecorder *)recorder didFailedRecordVideo:(NSError *)error;
- (void)recorder:(PLHKMediaRecorder *)recorder didConfigurationAsset:(AVMutableComposition *)asset withVideoComposition:(AVVideoComposition *)videoComposition;
//- (void)recorder:(HKMediaRecorder *)recorder didConfigurationAsset:(AVMutableComposition *)asset withVideoComposition:(AVVideoComposition *)videoComposition reverseAsset:(AVAsset *)reverseAsset;

- (void)recorder:(PLHKMediaRecorder *)recorder willDeleteDuration:(CMTime)duration;
- (void)recorderDidChangedToPauseRecordStatus:(PLHKMediaRecorder *)recorder;

@optional
- (void)recorder:(PLHKMediaRecorder *)recorder didExportVideoAsset:(AVAsset *)asset;

@end

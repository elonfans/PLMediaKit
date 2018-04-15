//
//  HKMediaRecorder.m
//  HKMediaRecorderKit
//
//  Created by HuangKai on 15/10/30.
//  Copyright © 2015年 KayWong. All rights reserved.
//

//#import "ViewController.h"
#import "PLHKMediaRecorder.h"
#import "PLHKMediaRecorderTools.h"
#import "PLSDAVAssetExportSession.h"
#import <Accelerate/Accelerate.h>
#import "UIImage+PLExtends.h"
#import "PLVideoRecorderHelper.h"
#import "PLFXBlurView.h"

#define COUNT_DUR_TIMER_INTERVAL 0.025
#define VIDEO_FOLDER @"HK_MediaKit_Videos"

static void *CapturingStillImageContext = &CapturingStillImageContext;
static void *SessionRunningContext = &SessionRunningContext;
static void *MovieOutputRecordingContext = &MovieOutputRecordingContext;
static void *ExposureTargetOffsetContext = &ExposureTargetOffsetContext;

@interface PLHKMediaRecorder ()
@property (nonatomic, strong) PLSDAVAssetExportSession *exporterNew;
@property (nonatomic, strong) NSTimer *timer;
@property (nonatomic, strong) NSMutableArray *timeScaleArray;
@property (nonatomic, strong) NSMutableArray *offsetsArray;
@property (nonatomic, assign) BOOL alreadyAddObsever;
@property (nonatomic, assign) BOOL alreadyAddOutput;
@property (nonatomic) BOOL isExporting;
@property (nonatomic) BOOL autoResumeCamaraDone;

@property (nonatomic) BOOL isNeedToRestartRunningSession;

@property (nonatomic) BOOL isKVORunning;

@end

@implementation PLHKMediaRecorder
@synthesize isTorchSupported = _isTorchSupported;

- (instancetype)init
{
    self = [super init];
    if (self) {
        //initDefaultTimeScale
        _currentTimeScale = 1.0f;
        _isRecording = NO;
        _recordMode = HKRecordModeAuto;
        _alreadyAddObsever = NO;
        _alreadyAddOutput = NO;
        _isKVORunning = NO;
        // Create the AVCaptureSession.
        self.session = [[AVCaptureSession alloc] init];
        self.session.sessionPreset = [PLHKMediaRecorderTools AVCaptureSessionPresetConfigByMachineModel];

        // Setup the preview view.
        self.previewView = [[PLHKPreviewView alloc] init];
        self.previewView.alpha = 0;
        self.previewView.userInteractionEnabled = YES;
        self.previewView.session = self.session;
        AVCaptureVideoPreviewLayer *previewLayer = (AVCaptureVideoPreviewLayer *) self.previewView.layer;
        previewLayer.connection.videoOrientation = AVCaptureVideoOrientationPortrait;
        previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;

        // Communicate with the session and other session objects on this queue.
        self.sessionQueue = dispatch_queue_create("session queue", DISPATCH_QUEUE_SERIAL);

        self.setupResult = HKCamSetupResultSuccess;

        // Check video authorization status. Video access is required and audio access is optional.
        // If audio access is denied, audio is not recorded during movie recording.
        switch ([AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo]) {
            case AVAuthorizationStatusAuthorized: {
                // The user has previously granted access to the camera.
                break;
            }
            case AVAuthorizationStatusNotDetermined: {
                // The user has not yet been presented with the option to grant video access.
                // We suspend the session queue to delay session setup until the access request has completed to avoid
                // asking the user for audio access if video access is denied.
                // Note that audio access will be implicitly requested when we create an AVCaptureDeviceInput for audio during session setup.
                dispatch_suspend(self.sessionQueue);
                [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo
                                         completionHandler:^(BOOL granted) {
                                             if (!granted) {
                                                 self.setupResult = HKCamSetupResultCameraNotAuthorized;
                                             }
                                             dispatch_resume(self.sessionQueue);
                                         }];
                break;
            }
            default: {
                // The user has previously denied access.
                self.setupResult = HKCamSetupResultCameraNotAuthorized;
                break;
            }
        }

        // Setup the capture session.
        // In general it is not safe to mutate an AVCaptureSession or any of its inputs, outputs, or connections from multiple threads at the same time.
        // Why not do all of this on the main queue?
        // Because -[AVCaptureSession startRunning] is a blocking call which can take a long time. We dispatch session setup to the sessionQueue
        // so that the main queue isn't blocked, which keeps the UI responsive.
        dispatch_async(self.sessionQueue, ^{
            if (self.setupResult != HKCamSetupResultSuccess) {
                return;
            }

            self.backgroundRecordingID = UIBackgroundTaskInvalid;
            NSError *error = nil;

            AVCaptureDevice *videoDevice = [[self class] deviceWithMediaType:AVMediaTypeVideo preferringPosition:AVCaptureDevicePositionBack];
            
            // Camera && Torch Support
            if ([videoDevice hasFlash]) {
                _isTorchSupported = YES;
            } else {
                _isTorchSupported = NO;
            }
            self.isUsingFrontCamera = NO;

            self.videoDevice = videoDevice;
            AVCaptureDeviceInput *videoDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:videoDevice error:&error];

            if (!videoDeviceInput) {
                NSLog(@"Could not create video device input: %@", error);
            }

            [self.session beginConfiguration];

            if ([self.session canAddInput:videoDeviceInput]) {
                [self.session addInput:videoDeviceInput];
                self.videoDeviceInput = videoDeviceInput;

                dispatch_async(dispatch_get_main_queue(), ^{
                    // Why are we dispatching this to the main queue?
                    // Because AVCaptureVideoPreviewLayer is the backing layer for AAPLPreviewView and UIView
                    // can only be manipulated on the main thread.
                    // Note: As an exception to the above rule, it is not necessary to serialize video orientation changes
                    // on the AVCaptureVideoPreviewLayer’s connection with other session manipulation.

                    // Use the status bar orientation as the initial video orientation. Subsequent orientation changes are handled by
                    // -[viewWillTransitionToSize:withTransitionCoordinator:].
                    //                    UIInterfaceOrientation statusBarOrientation = [UIApplication sharedApplication].statusBarOrientation;
                    AVCaptureVideoOrientation initialVideoOrientation = AVCaptureVideoOrientationPortrait;
                    //                    if ( statusBarOrientation != UIInterfaceOrientationUnknown ) {
                    //                        initialVideoOrientation = (AVCaptureVideoOrientation)statusBarOrientation;
                    //                    }

                    AVCaptureVideoPreviewLayer *previewLayer = (AVCaptureVideoPreviewLayer *) self.previewView.layer;
                    previewLayer.connection.videoOrientation = initialVideoOrientation;
                });
            } else {
                NSLog(@"Could not add video device input to the session");
                self.setupResult = HKCamSetupResultSessionConfigurationFailed;
            }

            AVCaptureDevice *audioDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio];
            AVCaptureDeviceInput *audioDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:audioDevice error:&error];

            if (!audioDeviceInput) {
                NSLog(@"Could not create audio device input: %@", error);
            }

            if ([self.session canAddInput:audioDeviceInput]) {
                [self.session addInput:audioDeviceInput];
            } else {
                NSLog(@"Could not add audio device input to the session");
            }
            if (!self.alreadyAddOutput) {
                [self.session addObserver:self forKeyPath:@"running" options:NSKeyValueObservingOptionNew context:SessionRunningContext];
                _isKVORunning = YES;
            }

            [self.session commitConfiguration];
        });
    }

    return self;
}

- (NSMutableArray *)segments
{
    if (!_segments) {
        _segments = [NSMutableArray array];
    }
    return _segments;
}
- (NSMutableArray *)segmentsCamaraPositionArray
{
    if (!_segmentsCamaraPositionArray) {
        _segmentsCamaraPositionArray = [NSMutableArray array];
    }
    return _segmentsCamaraPositionArray;
}
- (NSMutableArray *)timeScaleArray
{
    if (!_timeScaleArray) {
        _timeScaleArray = [NSMutableArray array];
    }
    return _timeScaleArray;
}
- (void)setRecordMode:(HKRecordMode)recordMode
{
    _recordMode = recordMode;
    if (recordMode == HKRecordModeAuto) {
        [self closeNightMode];
    } else {
        [self openNightMode];
    }
}
- (void)startRunning
{
    dispatch_async(self.sessionQueue, ^{
        switch (self.setupResult) {
            case HKCamSetupResultSuccess: {
                // Only setup observers and start the session running if setup succeeded.
                if (self.session.isRunning) {
                    return;
                }
                [self.session startRunning];
                self.isNeedToRestartRunningSession = NO;
                self.sessionRunning = self.session.isRunning;
                break;
            }
            case HKCamSetupResultCameraNotAuthorized: {
                dispatch_async(dispatch_get_main_queue(), ^{
                                   //                    NSString *message = NSLocalizedString( @"AVCam doesn't have permission to use the camera, please change privacy settings", @"Alert message when the user has denied access to the camera" );

                               });
                break;
            }
            case HKCamSetupResultSessionConfigurationFailed: {
                dispatch_async(dispatch_get_main_queue(), ^{
                                   //                    NSString *message = NSLocalizedString( @"Unable to capture media", @"Alert message when something goes wrong during capture session configuration" );

                               });
                break;
            }
        }
    });
}
- (void)startRecording
{
    [[self class] createVideoFolderIfNotExist];
    dispatch_async(self.sessionQueue, ^{
        if (!self.movieFileOutput.isRecording && !self.isRecording) {
            if ([UIDevice currentDevice].isMultitaskingSupported) {
                // Setup background task. This is needed because the -[captureOutput:didFinishRecordingToOutputFileAtURL:fromConnections:error:]
                // callback is not received until AVCam returns to the foreground unless you request background execution time.
                // This also ensures that there will be time to write the file to the photo library when AVCam is backgrounded.
                // To conclude this background execution, -endBackgroundTask is called in
                // -[captureOutput:didFinishRecordingToOutputFileAtURL:fromConnections:error:] after the recorded file has been saved.
                self.backgroundRecordingID = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:nil];
            }

            // Update the orientation on the movie file output video connection before starting recording.
            AVCaptureConnection *connection = [self.movieFileOutput connectionWithMediaType:AVMediaTypeVideo];
            AVCaptureVideoPreviewLayer *previewLayer = (AVCaptureVideoPreviewLayer *) self.previewView.layer;
            connection.videoOrientation = previewLayer.connection.videoOrientation;

            // Turn OFF flash for video recording.
            //            [[self class] setFlashMode:AVCaptureFlashModeOff forDevice:self.videoDeviceInput.device];

            // Start recording to a temporary file.
            NSURL *fileURL = [NSURL fileURLWithPath:[[self class] getVideoSaveFilePathString]];

            NSLog(@"__________________________startRecording%@", @([[NSDate date] timeIntervalSince1970]));
            _isRecording = YES;
            [_movieFileOutput startRecordingToOutputFileURL:fileURL recordingDelegate:self];
        }
    });
}
- (void)resumeInterruptedSession
{
    dispatch_async(self.sessionQueue, ^{
        // The session might fail to start running, e.g., if a phone or FaceTime call is still using audio or video.
        // A failure to start the session running will be communicated via a session runtime error notification.
        // To avoid repeatedly failing to start the session running, we only try to restart the session running in the
        // session runtime error handler if we aren't trying to resume the session running.
        [self.session startRunning];
        self.sessionRunning = self.session.isRunning;
        if (!self.session.isRunning) {
            dispatch_async(dispatch_get_main_queue(), ^{
            });
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                               //重新打开成功
                           });
        }
    });
}
- (void)startCountDurTimer
{
    _float_currentDur = 0;
    if (self.timer) {
        [self.timer invalidate];
    }
    self.timer = [NSTimer scheduledTimerWithTimeInterval:COUNT_DUR_TIMER_INTERVAL target:self selector:@selector(onTimer:) userInfo:nil repeats:YES];

    NSLog(@"StartRecording.................");
}
- (void)onTimer:(NSTimer *)timer
{
    _float_totalDur = _float_totalDur + (COUNT_DUR_TIMER_INTERVAL * self.currentTimeScale);
    _float_currentDur = _float_currentDur + (COUNT_DUR_TIMER_INTERVAL * self.currentTimeScale);
    NSLog(@"_float_totalDur_______%@", @(_float_totalDur));
    if (self.delegate != nil && [self.delegate conformsToProtocol:@protocol(PLHKMediaRecorderDelegate)] && [self.delegate respondsToSelector:@selector(recorder:didRecordedDuration:totalDuration:)]) {
        [self.delegate recorder:self didRecordedDuration:_float_currentDur totalDuration:_float_totalDur];
    }
}
- (void)stopCountDurTimer
{
    [self.timer invalidate];
    self.timer = nil;
}
- (void)stopRecording
{
    //无论怎么怎么调用，都是马上暂停
    _isPreparingToExportRecording = YES;
    [self pause];
    if (!_movieFileOutput.recording) {
        [self beginExportMergedSegmentAsset];
    }
}
- (void)stopRunning
{
    if (self.timer) {
        [self stopRecording];
    }
    [self.session stopRunning];
    NSLog(@"session停止running");
}
- (void)pause
{
    _isRecording = NO;
    [_movieFileOutput stopRecording];
    NSLog(@"_________________________pause");
    [self stopCountDurTimer];
}

- (void)beginExportMergedSegmentAsset
{
    if (!_movieFileOutput.isRecording && !self.isExporting) {
        [self mergeSegmsWithFileURLs:self.segments];
    }
}
#pragma mark - 删除当前段的Asset
- (void)deleteCurrentAsset
{
    AVAsset *asset = [AVAsset assetWithURL:[self.segments lastObject]];
    [asset loadValuesAsynchronouslyForKeys:@[ @"duration" ]
                         completionHandler:^{
                             NSFileManager *defaultManager = [NSFileManager defaultManager];
                             if (self.delegate != nil && [self.delegate conformsToProtocol:@protocol(PLHKMediaRecorderDelegate)] && [self.delegate respondsToSelector:@selector(recorder:willDeleteDuration:)]) {
                                 if ([defaultManager removeItemAtURL:[self.segments lastObject] error:nil]) {
                                     [self removeLastSegmentInfo];
                                     [self.delegate recorder:self willDeleteDuration:asset.duration];
                                 }
                             }
                         }];
}
- (void)removeLastSegmentInfo
{
    [self.segments removeLastObject];
    [self.timeScaleArray removeLastObject];
    [self.segmentsCamaraPositionArray removeLastObject];
}
#pragma mark - 合成AVAsset
- (void)mergeSegmsWithFileURLs:(NSArray *)fileURLArray
{
    self.isExporting = YES;
    NSError *error = nil;

    CGSize renderSize = CGSizeMake(0, 0);

    NSMutableArray *layerInstructionArray = [[NSMutableArray alloc] init];

    AVMutableComposition *mixComposition = [[AVMutableComposition alloc] init];

    CMTime totalDuration = kCMTimeZero;

    //先去assetTrack 也为了取renderSize
    NSMutableArray *assetTrackArray = [[NSMutableArray alloc] init];
    NSMutableArray *assetAudioTrackArray = [[NSMutableArray alloc] init];
    NSMutableArray *assetArray = [[NSMutableArray alloc] init];

    for (NSURL *fileURL in fileURLArray) {
        AVURLAsset *asset = [AVURLAsset URLAssetWithURL:fileURL options:@{ AVURLAssetPreferPreciseDurationAndTimingKey : @YES }];
        if (!asset) {
            continue;
        }
        NSLog(@"%@---%@", asset.tracks, [asset tracksWithMediaType:AVMediaTypeVideo]);

        [assetArray addObject:asset];
        AVAssetTrack *assetVideoTrack;

        if ([[asset tracksWithMediaType:AVMediaTypeVideo] count] > 0) {
            assetVideoTrack = [[asset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0];
        } else {
            if (self.delegate != nil && [self.delegate conformsToProtocol:@protocol(PLHKMediaRecorderDelegate)] && [self.delegate respondsToSelector:@selector(recorder:didFailedConfigSegments:)]) {
                NSDictionary *userInfo = [NSDictionary dictionaryWithObject:@"无法获取视频Track" forKey:NSLocalizedDescriptionKey];
                NSError *error = [NSError errorWithDomain:@"com.kaywong.MediaRecordKit" code:-9999 userInfo:userInfo];
                [self.delegate recorder:self didFailedConfigSegments:error];
            }
            self.isExporting = NO;
            return;
        }

        [assetTrackArray addObject:assetVideoTrack];
        renderSize.width = MAX(renderSize.width, assetVideoTrack.naturalSize.width);
        renderSize.height = MAX(renderSize.height, assetVideoTrack.naturalSize.height);

        AVAssetTrack *assetAudioTrack;
        if ([asset tracksWithMediaType:AVMediaTypeAudio].count > 0) {
            assetAudioTrack = [[asset tracksWithMediaType:AVMediaTypeAudio] objectAtIndex:0];
        } else {
            if (self.delegate != nil && [self.delegate conformsToProtocol:@protocol(PLHKMediaRecorderDelegate)] && [self.delegate respondsToSelector:@selector(recorder:didFailedConfigSegments:)]) {
                NSDictionary *userInfo = [NSDictionary dictionaryWithObject:@"无法获取音频Track" forKey:NSLocalizedDescriptionKey];
                NSError *error = [NSError errorWithDomain:@"com.kaywong.MediaRecordKit" code:-9999 userInfo:userInfo];
                [self.delegate recorder:self didFailedConfigSegments:error];
            }
            self.isExporting = NO;
            return;
        }

        [assetAudioTrackArray addObject:assetAudioTrack];
    }
    NSLog(@"获取完视频轨道");

    CGFloat renderW = [PLHKMediaRecorderTools videoSizeConfigByMachineModel].width;
    CGFloat renderH = [PLHKMediaRecorderTools videoSizeConfigByMachineModel].height;
    AVMutableCompositionTrack *videoTrack = [mixComposition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];

    // add audio
    AVMutableCompositionTrack *audioCompositionTrack = [mixComposition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];

    CMTime curTotalDuration = kCMTimeZero;
    for (int i = 0; i < [assetTrackArray count]; i++) {
        AVAssetTrack *assetTrack = [assetTrackArray objectAtIndex:i];
        //        AVMutableCompositionTrack *videoTrack = [mixComposition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
        CGFloat timeScale = [self.timeScaleArray[i] doubleValue];
        CGFloat timeToCut = i == 0 ? 0.33 : 0.088;
        //        if (timeScale != 0 && timeScale != 1) {
        //            timeToCut = timeToCut/timeScale*2;
        //        }

        curTotalDuration = totalDuration;
        CMTime cutTime = CMTimeMakeWithSeconds(timeToCut, assetTrack.timeRange.duration.timescale);
        CMTime tempTime = assetTrack.timeRange.duration;
        if (i == assetTrackArray.count - 1) { //如果是最后一个视频片段
            tempTime = CMTimeMake(assetTrack.timeRange.duration.value + assetTrack.timeRange.duration.timescale * 2, assetTrack.timeRange.duration.timescale);
        }
        [videoTrack insertTimeRange:CMTimeRangeMake(cutTime, CMTimeSubtract(tempTime, cutTime))
                            ofTrack:assetTrack
                             atTime:curTotalDuration
                              error:&error];

        curTotalDuration = totalDuration;
        AVAssetTrack *audioTrack = [assetAudioTrackArray objectAtIndex:i];
        [audioCompositionTrack insertTimeRange:CMTimeRangeMake(cutTime, CMTimeSubtract(audioTrack.timeRange.duration, cutTime))
                                       ofTrack:audioTrack
                                        atTime:curTotalDuration
                                         error:&error];

        CMTime trimmedDuration = CMTimeMultiplyByFloat64(CMTimeSubtract(assetTrack.timeRange.duration, cutTime), timeScale);
        [mixComposition scaleTimeRange:CMTimeRangeMake(totalDuration, CMTimeSubtract(assetTrack.timeRange.duration, cutTime)) toDuration:trimmedDuration];

        //fix orientationissue
        AVMutableVideoCompositionLayerInstruction *layerInstruciton = [AVMutableVideoCompositionLayerInstruction videoCompositionLayerInstructionWithAssetTrack:videoTrack];

        CGFloat rate;
        rate = renderW / MIN(assetTrack.naturalSize.width, assetTrack.naturalSize.height);
        CGAffineTransform layerTransform = assetTrack.preferredTransform;

        layerTransform = CGAffineTransformConcat(layerTransform, CGAffineTransformMake(1, 0, 0, 1, 0, -(assetTrack.naturalSize.width - assetTrack.naturalSize.height) / 2.0)); //向上移动取中部影响
        //如果需要截取成正方形的视频则需要上面那行

        if (self.segmentsCamaraPositionArray.count > i && [self.segmentsCamaraPositionArray[i] integerValue] == AVCaptureDevicePositionFront) {
            layerTransform = CGAffineTransformScale(layerTransform, 1, -1);
            layerTransform = CGAffineTransformTranslate(layerTransform, 0, -layerTransform.tx);
        }
        if (self.segmentsCamaraPositionArray.count > i && [self.segmentsCamaraPositionArray[i] integerValue] == AVCaptureDevicePositionBack && renderH == 720) {
            layerTransform.tx = 540.0f;
        }

        layerTransform = CGAffineTransformScale(layerTransform, rate, rate); //放缩，解决前后摄像结果大小不对称
        layerTransform.tx = rate * layerTransform.tx;
        layerTransform.ty = rate * layerTransform.ty;
        //        layerTransform  = CGAffineTransformRotate(layerTransform, M_PI*0.38);
        [layerInstruciton setTransform:layerTransform atTime:kCMTimeZero];
        //        [layerInstruciton setOpacity:0.3f atTime:totalDuration];
        totalDuration = mixComposition.duration;
        //data
        [layerInstructionArray addObject:layerInstruciton];
    }
    NSLog(@"合成完音频");
    NSLog(@"合成完视频");

    //export
    //    NSString *filePath = [[self class] getVideoMergeFilePathString];

    //    NSURL *mergeFileURL = [NSURL fileURLWithPath:filePath];
    AVMutableVideoCompositionInstruction *mainInstruciton = [AVMutableVideoCompositionInstruction videoCompositionInstruction];
    mainInstruciton.timeRange = CMTimeRangeMake(kCMTimeZero, totalDuration);
    mainInstruciton.layerInstructions = layerInstructionArray;
    AVMutableVideoComposition *mainCompositionInst = [AVMutableVideoComposition videoComposition];
    mainCompositionInst.instructions = @[ mainInstruciton ];
    mainCompositionInst.frameDuration = CMTimeMake(1, 15);

    mainCompositionInst.renderSize = CGSizeMake([PLHKMediaRecorderTools videoSizeConfigByMachineModel].width, [PLHKMediaRecorderTools videoSizeConfigByMachineModel].height);

    //add video tail
    AVAssetTrack *lastVideoTrack = [assetTrackArray lastObject];
    AVAssetImageGenerator *imageGenerator = [[AVAssetImageGenerator alloc] initWithAsset:lastVideoTrack.asset];
    imageGenerator.appliesPreferredTrackTransform = YES;
    UIImage *lastImage;
    // calculate the midpoint time of video
    Float64 duration = CMTimeGetSeconds([videoTrack.asset duration]);
    CMTime midpoint = CMTimeMakeWithSeconds(duration, 600);
    CMTime actualTime;
    CGImageRef centerFrameImage = [imageGenerator copyCGImageAtTime:midpoint
                                                         actualTime:&actualTime
                                                              error:nil];
    if (centerFrameImage != NULL) {
        lastImage = [[[UIImage alloc] initWithCGImage:centerFrameImage] blurredImageWithRadius:20 iterations:3 tintColor:nil];
        // Release the CFRetained image
        CGImageRelease(centerFrameImage);
    }
    [PLVideoRecorderHelper addVideoTail:mainCompositionInst lastImage:lastImage totalDuration:totalDuration];

    //开始合成倒序的视频
    //    AVAsset *newAsset = [AVUtilities assetByReversingAsset:[mixComposition copy] videoComposition:[mainCompositionInst copy] outputURL:[NSURL fileURLWithPath:[[self class] getVideoSaveFilePathString]]];

    // 片尾
    //    CGSize size = mainCompositionInst.renderSize;
    //
    //    CALayer *waterMarkLayer = [CALayer layer];
    //    waterMarkLayer.frame = CGRectMake(size.width / 2 - 134 / 2, size.height / 2 - 48 / 2, 134, 48);
    //    waterMarkLayer.contents = (id)[UIImage imageNamed:@"resource.bundle/videoTrailer@3x.png"].CGImage;
    //
    //    CALayer *overlayLayer = [CALayer layer];
    //    [overlayLayer addSublayer:waterMarkLayer];
    //    overlayLayer.frame = CGRectMake(0, 0, size.width, size.height);
    //    [overlayLayer setMasksToBounds:YES];
    //    CALayer *parentLayer = [CALayer layer];
    //    CALayer *videoLayer = [CALayer layer];
    //    parentLayer.frame = CGRectMake(0, 0, size.width, size.height);
    //    videoLayer.frame = CGRectMake(0, 0, size.width, size.height);
    //
    //    // overlayLayer放在了videolayer的上面，所以水印总是显示在视频之上的。
    //    [parentLayer addSublayer:videoLayer];
    //    [parentLayer addSublayer:overlayLayer];
    //
    //    CABasicAnimation *fadeOutAnimation = [CABasicAnimation animationWithKeyPath:@"opacity"];
    //    fadeOutAnimation.fromValue = @0.0f;
    //    fadeOutAnimation.toValue = @1.0f;
    //    fadeOutAnimation.additive = NO;
    //    fadeOutAnimation.removedOnCompletion = NO;
    //    fadeOutAnimation.beginTime = CMTimeGetSeconds(totalDuration) - 2;
    //    fadeOutAnimation.duration = 1;
    //    fadeOutAnimation.autoreverses = NO;
    //    fadeOutAnimation.fillMode = kCAFillModeBoth;
    //    [overlayLayer addAnimation:fadeOutAnimation forKey:@"opacity"];
    //
    //    mainCompositionInst.animationTool = [AVVideoCompositionCoreAnimationTool videoCompositionCoreAnimationToolWithPostProcessingAsVideoLayer:videoLayer inLayer:parentLayer];

    self.isExporting = NO;
    NSLog(@"配置完合成的视频");

    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.delegate != nil && [self.delegate conformsToProtocol:@protocol(PLHKMediaRecorderDelegate)] && [self.delegate respondsToSelector:@selector(recorder:didConfigurationAsset:withVideoComposition:)]) {
            [self.delegate recorder:self didConfigurationAsset:mixComposition withVideoComposition:mainCompositionInst];
        }
    });
    //    self.exporterNew = [[PLSDAVAssetExportSession alloc]initWithAsset:mixComposition];
    //    self.exporterNew.videoComposition = mainCompositionInst;
    //    self.exporterNew.outputURL = mergeFileURL;
    //    self.exporterNew.outputFileType = AVFileTypeMPEG4;
    //    self.exporterNew.shouldOptimizeForNetworkUse = YES;
    //    self.exporterNew.videoSettings = @{
    //                                   AVVideoCodecKey:AVVideoCodecH264,
    //                                   AVVideoWidthKey:@([HKMediaRecorderTools videoSizeConfigByMachineModel].width), // frame
    //                                   AVVideoHeightKey:@([HKMediaRecorderTools videoSizeConfigByMachineModel].height),
    //                                   AVVideoScalingModeKey:AVVideoScalingModeResizeAspectFill, // resize
    //                                   AVVideoCompressionPropertiesKey:@{
    //                                           AVVideoAverageBitRateKey:@(600000),  // Bit rate
    //                                           AVVideoProfileLevelKey: AVVideoProfileLevelH264BaselineAutoLevel,
    //                                           },
    //                                   };
    //
    //    // audio Setting
    //    self.exporterNew.audioSettings = @{
    //                                   AVFormatIDKey:@(kAudioFormatMPEG4AAC),  // ;
    //                                   AVNumberOfChannelsKey:@1,
    //                                   AVSampleRateKey:@44100,   // hz?
    //                                   AVEncoderBitRateKey:@128000, // bitrate?
    //                                   };
    //    __weak typeof(self) weakSelf = self;
    //
    //    AVAssetExportSession *exporter = [[AVAssetExportSession alloc] initWithAsset:mixComposition.copy presetName:AVAssetExportPreset960x540];
    //    exporter.videoComposition = mainCompositionInst.copy;
    //    exporter.outputURL = mergeFileURL;
    //    exporter.outputFileType = AVFileTypeMPEG4;
    //    exporter.shouldOptimizeForNetworkUse = YES;
    //
    //
    //    [exporter exportAsynchronouslyWithCompletionHandler:^{
    //        dispatch_async(dispatch_get_main_queue(), ^{
    //            AVAssetExportSession *hehe = exporter;
    //            NSLog(@"hehe error %@", hehe.error);
    //
    //            UISaveVideoAtPathToSavedPhotosAlbum(filePath, nil, nil, nil);
    //
    //            NSString *newFilePath = [filePath stringByAppendingPathComponent:@"hehehe.mp4"];
    //            NSURL *newURL = [NSURL fileURLWithPath:newFilePath];
    //            self.exporterNew.outputURL = newURL;
    //
    //            [self.exporterNew exportAsynchronouslyWithCompletionHandler:^{
    //                if (weakSelf.exporterNew.status == AVAssetExportSessionStatusCompleted) {
    //
    //                    NSLog(@"AVAssetExportSessionStatusCompleted");
    //
    //                    // TODO：转码后的视频URL：outputURL，处理后的视频URL；videoPreViewImage 视频预览图
    //                    dispatch_async(dispatch_get_main_queue(), ^{
    //                        AVAsset *exportAsset = [AVAsset assetWithURL:newURL];
    //                        if (weakSelf.delegate != nil && [self.delegate conformsToProtocol:@protocol(HKMediaRecorderDelegate)] && [self.delegate respondsToSelector:@selector(recorder:didConfigurationAsset:withVideoComposition:)]) {
    //                            UISaveVideoAtPathToSavedPhotosAlbum(newFilePath, nil, nil, nil);
    //
    //                            [weakSelf.delegate recorder:self didConfigurationAsset:mixComposition withVideoComposition:mainCompositionInst];
    //                        }
    //
    //                    });
    //
    //                }else if(weakSelf.exporterNew.status == AVAssetExportSessionStatusFailed){
    //                    NSLog(@"AVAssetExportSessionStatusFailed");
    //                }else if(weakSelf.exporterNew.status == AVAssetExportSessionStatusExporting){
    //                    NSLog(@"AVAssetExportSessionStatusExporting....");
    //
    //                }else if(weakSelf.exporterNew.status == AVAssetExportSessionStatusCancelled){
    //                    NSLog(@"AVAssetExportSessionStatusCancelled");
    //
    //                }
    //            }];
    //            AVAsset *exportAsset = [AVAsset assetWithURL:mergeFileURL];
    //            if (self.delegate != nil && [self.delegate conformsToProtocol:@protocol(HKMediaRecorderDelegate)] && [self.delegate respondsToSelector:@selector(recorder:didExportVideoAsset:)]) {
    //                [self.delegate recorder:self didExportVideoAsset:exportAsset];
    //            }
    //
    //        });
    //    }];
}

+ (NSString *)getVideoSaveFilePathString
{
    //    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    //  NSString *path = [paths objectAtIndex:0];

    NSString *path = [NSString stringWithFormat:@"%@/tmp/", NSHomeDirectory()];

    path = [path stringByAppendingPathComponent:VIDEO_FOLDER];

    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];

    formatter.dateFormat = @"yyyyMMddHHmmss";

    NSString *nowTimeStr = [NSString stringWithFormat:@"%@", @([[NSDate date] timeIntervalSince1970])];
    ;

    NSString *fileName = [[path stringByAppendingPathComponent:nowTimeStr] stringByAppendingString:@".mp4"];

    return fileName;
}
+ (NSString *)getVideoMergeFilePathString
{
    //    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    //  NSLog(@"",);
    NSString *path = [NSString stringWithFormat:@"%@/tmp/", NSHomeDirectory()];
    // [paths objectAtIndex:0];

    path = [path stringByAppendingPathComponent:VIDEO_FOLDER];

    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"yyyyMMddHHmmss";
    NSString *nowTimeStr = [NSString stringWithFormat:@"%@", @([[NSDate date] timeIntervalSince1970])];
    ;

    NSString *fileName = [[path stringByAppendingPathComponent:nowTimeStr] stringByAppendingString:@"merge.mp4"];

    return fileName;
}
+ (BOOL)createVideoFolderIfNotExist
{
    // NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *path = [NSString stringWithFormat:@"%@/tmp/", NSHomeDirectory()];

    //[paths objectAtIndex:0];

    NSString *folderPath = [path stringByAppendingPathComponent:VIDEO_FOLDER];

    NSFileManager *fileManager = [NSFileManager defaultManager];
    BOOL isDir = FALSE;
    BOOL isDirExist = [fileManager fileExistsAtPath:folderPath isDirectory:&isDir];

    if (!(isDirExist && isDir)) {
        BOOL bCreateDir = [fileManager createDirectoryAtPath:folderPath withIntermediateDirectories:YES attributes:nil error:nil];
        if (!bCreateDir) {
            NSLog(@"创建文件夹失败");
            return NO;
        }
        return YES;
    }
    return YES;
}
- (void)removeAllSegments
{
    NSString *path = [NSString stringWithFormat:@"%@/tmp/", NSHomeDirectory()];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    [fileManager removeItemAtPath:path error:nil];
    [self.segments removeAllObjects];
    [self.timeScaleArray removeAllObjects];
    [self.segmentsCamaraPositionArray removeAllObjects];
}
- (void)resetRescordSession
{
    [self removeAllSegments];
    _isPreparingToExportRecording = NO;
    _isRecording = NO;
    _currentTimeScale = 1;
    _isExporting = NO;
    _float_currentDur = 0;
    _float_totalDur = 0;
}
#pragma mark KVO and Notifications

- (void)addObservers
{
    [self.movieFileOutput addObserver:self forKeyPath:@"recording" options:NSKeyValueObservingOptionNew context:MovieOutputRecordingContext];
    [self.stillImageOutput addObserver:self forKeyPath:@"capturingStillImage" options:NSKeyValueObservingOptionNew context:CapturingStillImageContext];
    if ([[[UIDevice currentDevice] systemVersion] integerValue] >= 8.0) {
        [self addObserver:self forKeyPath:@"videoDevice.exposureTargetOffset" options:NSKeyValueObservingOptionNew context:ExposureTargetOffsetContext];
    }

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(subjectAreaDidChange:) name:AVCaptureDeviceSubjectAreaDidChangeNotification object:self.videoDeviceInput.device];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(sessionRuntimeError:) name:AVCaptureSessionRuntimeErrorNotification object:self.session];
    // A session can only run when the app is full screen. It will be interrupted in a multi-app layout, introduced in iOS 9,
    // see also the documentation of AVCaptureSessionInterruptionReason. Add observers to handle these session interruptions
    // and show a preview is paused message. See the documentation of AVCaptureSessionWasInterruptedNotification for other
    // interruption reasons.
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(sessionWasInterrupted:) name:AVCaptureSessionWasInterruptedNotification object:self.session];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(sessionInterruptionEnded:) name:AVCaptureSessionInterruptionEndedNotification object:self.session];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidBecomeActiveNotification:) name:UIApplicationDidBecomeActiveNotification object:nil];
    _alreadyAddObsever = YES;
}
- (void)removeObservers
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    if (_isKVORunning) {
        [self.session removeObserver:self forKeyPath:@"running" context:SessionRunningContext];
    }
    if (self.alreadyAddObsever) {
        [self.movieFileOutput removeObserver:self forKeyPath:@"recording" context:MovieOutputRecordingContext];
        [self.stillImageOutput removeObserver:self forKeyPath:@"capturingStillImage" context:CapturingStillImageContext];
        if ([[[UIDevice currentDevice] systemVersion] integerValue] >= 8.0) {
            [self removeObserver:self forKeyPath:@"videoDevice.exposureTargetOffset" context:ExposureTargetOffsetContext];
        }
    }
}
- (void)dealloc
{
    [self removeObservers];
}
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    id newValue = change[NSKeyValueChangeNewKey];

    if (context == CapturingStillImageContext) {
        BOOL isCapturingStillImage = [change[NSKeyValueChangeNewKey] boolValue];

        if (isCapturingStillImage) {
            dispatch_async(dispatch_get_main_queue(), ^{
                self.previewView.layer.opacity = 0.0;
                [UIView animateWithDuration:0.25
                                 animations:^{
                                     self.previewView.layer.opacity = 1.0;
                                 }];
            });
        }
    } else if (context == SessionRunningContext) {
        BOOL isSessionRunning = [change[NSKeyValueChangeNewKey] boolValue];
        if (isSessionRunning && !self.alreadyAddObsever && !self.alreadyAddOutput) {
            [self.session beginConfiguration];
            NSLog(@"session状态变成running");

            AVCaptureMovieFileOutput *movieFileOutput = [[AVCaptureMovieFileOutput alloc] init];
            movieFileOutput.movieFragmentInterval = kCMTimeInvalid;
            if ([self.session canAddOutput:movieFileOutput]) {
                [self.session addOutput:movieFileOutput];
                AVCaptureConnection *connection = [movieFileOutput connectionWithMediaType:AVMediaTypeVideo];
                if (connection.isVideoStabilizationSupported && [[[UIDevice currentDevice] systemVersion] integerValue] >= 8.0) {
                    connection.preferredVideoStabilizationMode = AVCaptureVideoStabilizationModeAuto;
                }

                self.movieFileOutput = movieFileOutput;
            } else {
                NSLog(@"Could not add movie file output to the session");
                self.setupResult = HKCamSetupResultSessionConfigurationFailed;
            }

            AVCaptureStillImageOutput *stillImageOutput = [[AVCaptureStillImageOutput alloc] init];
            if ([self.session canAddOutput:stillImageOutput]) {
                stillImageOutput.outputSettings = @{AVVideoCodecKey : AVVideoCodecJPEG};
                [self.session addOutput:stillImageOutput];
                self.stillImageOutput = stillImageOutput;
            } else {
                NSLog(@"Could not add still image output to the session");
                self.setupResult = HKCamSetupResultSessionConfigurationFailed;
            }
            [self.session commitConfiguration];

            [self addObservers];
            _alreadyAddOutput = YES;
        }

        if (isSessionRunning) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [UIView animateWithDuration:1.0
                                 animations:^{
                                     self.previewView.alpha = 1;
                                 }];
            });
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                [UIView animateWithDuration:1.0
                                 animations:^{
                                     self.previewView.alpha = 0;
                                 }];
            });
        }
        dispatch_async(dispatch_get_main_queue(), ^{
                           // Only enable the ability to change camera if the device has more than one camera.
                           //            self.cameraButton.enabled = isSessionRunning && ( [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo].count > 1 );
                           //            self.recordButton.enabled = isSessionRunning;
                           //            self.stillButton.enabled = isSessionRunning;
                       });
    } else if (context == ExposureTargetOffsetContext) {
        if (newValue && newValue != [NSNull null]) {
            float newExposureTargetOffset = [newValue floatValue];
            //            NSLog(@"%@",@(newExposureTargetOffset));
            //            if (self.videoDevice.position == AVCaptureDevicePositionBack) {
            //
            //            }
            if (newExposureTargetOffset < -5.0 && self.videoDevice.exposureMode != AVCaptureExposureModeCustom) {
                //                [HUDMessagePoster postTextString:@"如果拍摄环境光线弱，可以试一下双击屏幕喔！"];
            }
        }
    } else if (context == MovieOutputRecordingContext) {
        BOOL isRecording = [change[NSKeyValueChangeNewKey] boolValue];
        if (self.isPreparingToExportRecording && !isRecording) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self beginExportMergedSegmentAsset];
                _isPreparingToExportRecording = NO;
                NSLog(@"主动进入开始导出视频方法");
            });
        }
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}
- (void)subjectAreaDidChange:(NSNotification *)notification
{
    CGPoint devicePoint = CGPointMake(0.5, 0.5);
    [self focusWithMode:AVCaptureFocusModeContinuousAutoFocus exposeWithMode:self.videoDevice.exposureMode atDevicePoint:devicePoint monitorSubjectAreaChange:NO];
}
- (void)sessionRuntimeError:(NSNotification *)notification
{
    NSError *error = notification.userInfo[AVCaptureSessionErrorKey];
    NSLog(@"Capture session runtime error: %@", error);

    // Automatically try to restart the session running if media services were reset and the last start running succeeded.
    // Otherwise, enable the user to try to resume the session running.
    if (error.code == AVErrorMediaServicesWereReset) {
        dispatch_async(self.sessionQueue, ^{
            if (self.isSessionRunning) {
                [self.session startRunning];
                self.sessionRunning = self.session.isRunning;
            } else {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (!_autoResumeCamaraDone) {
                        [self resumeInterruptedSession];
                        _autoResumeCamaraDone = YES;
                    }
                    //                    self.resumeButton.hidden = NO;
                });
            }
        });
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!_autoResumeCamaraDone) {
                [self resumeInterruptedSession];
                _autoResumeCamaraDone = YES;
            }
        });
        //        self.resumeButton.hidden = NO;
    }
}
- (void)sessionWasInterrupted:(NSNotification *)notification
{
    // In some scenarios we want to enable the user to resume the session running.
    // For example, if music playback is initiated via control center while using AVCam,
    // then the user can let AVCam resume the session running, which will stop music playback.
    // Note that stopping music playback in control center will not automatically resume the session running.
    // Also note that it is not always possible to resume, see -[resumeInterruptedSession:].
    BOOL showResumeButton = NO;

    // In iOS 9 and later, the userInfo dictionary contains information on why the session was interrupted.
    if ([[[UIDevice currentDevice] systemVersion] integerValue] >= 9.0) {
        AVCaptureSessionInterruptionReason reason = [notification.userInfo[AVCaptureSessionInterruptionReasonKey] integerValue];
        NSLog(@"Capture session was interrupted with reason %ld", (long) reason);

        if (reason == AVCaptureSessionInterruptionReasonAudioDeviceInUseByAnotherClient ||
            reason == AVCaptureSessionInterruptionReasonVideoDeviceInUseByAnotherClient) {
            showResumeButton = YES;
        } else if (reason == AVCaptureSessionInterruptionReasonVideoDeviceNotAvailableWithMultipleForegroundApps) {
            // Simply fade-in a label to inform the user that the camera is unavailable.
            //应该弹出一个视图告知用户摄像头不可以用
        }
    } else {
        NSLog(@"Capture session was interrupted");
        showResumeButton = ([UIApplication sharedApplication].applicationState == UIApplicationStateInactive);
    }

    if (showResumeButton) {
        // Simply fade-in a button to enable the user to try to resume the session running.
        //应该弹出一个按钮让用户点击重新打开摄像头的会话
        self.isNeedToRestartRunningSession = showResumeButton;
    }
}

- (void)sessionInterruptionEnded:(NSNotification *)notification
{
    NSLog(@"Capture session interruption ended");
}
#pragma mark Device Configuration

- (void)focusWithMode:(AVCaptureFocusMode)focusMode exposeWithMode:(AVCaptureExposureMode)exposureMode atDevicePoint:(CGPoint)point monitorSubjectAreaChange:(BOOL)monitorSubjectAreaChange
{
    dispatch_async(self.sessionQueue, ^{
        AVCaptureDevice *device = self.videoDeviceInput.device;
        NSError *error = nil;
        if ([device lockForConfiguration:&error]) {
            // Setting (focus/exposure)PointOfInterest alone does not initiate a (focus/exposure) operation.
            // Call -set(Focus/Exposure)Mode: to apply the new point of interest.
            if (device.isFocusPointOfInterestSupported && [device isFocusModeSupported:focusMode]) {
                device.focusPointOfInterest = point;
                device.focusMode = focusMode;
            }

            if (device.isExposurePointOfInterestSupported && [device isExposureModeSupported:exposureMode]) {
                device.exposurePointOfInterest = point;
                device.exposureMode = exposureMode;
            }

            device.subjectAreaChangeMonitoringEnabled = monitorSubjectAreaChange;
            [device unlockForConfiguration];
        } else {
            NSLog(@"Could not lock device for configuration: %@", error);
        }
    });
}
+ (void)setFlashMode:(AVCaptureFlashMode)flashMode forDevice:(AVCaptureDevice *)device
{
    if (device.hasFlash && [device isFlashModeSupported:flashMode]) {
        NSError *error = nil;
        if ([device lockForConfiguration:&error]) {
            device.flashMode = flashMode;
            [device unlockForConfiguration];
        } else {
            NSLog(@"Could not lock device for configuration: %@", error);
        }
    }
}
+ (AVCaptureDevice *)deviceWithMediaType:(NSString *)mediaType preferringPosition:(AVCaptureDevicePosition)position
{
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:mediaType];
    AVCaptureDevice *captureDevice = devices.firstObject;
    for (AVCaptureDevice *device in devices) {
        if (device.position == position) {
            captureDevice = device;
            break;
        }
    }

    return captureDevice;
}
- (void)switchCamara
{
    AVCaptureDevice *currentVideoDevice = self.videoDeviceInput.device;
    AVCaptureDevicePosition preferredPosition = AVCaptureDevicePositionUnspecified;
    AVCaptureDevicePosition currentPosition = currentVideoDevice.position;

    switch (currentPosition) {
        case AVCaptureDevicePositionUnspecified:
        case AVCaptureDevicePositionFront:
            preferredPosition = AVCaptureDevicePositionBack;
            break;
        case AVCaptureDevicePositionBack:
            preferredPosition = AVCaptureDevicePositionFront;
            break;
    }

    self.isUsingFrontCamera = preferredPosition == AVCaptureDevicePositionFront;

    dispatch_async(self.sessionQueue, ^{

        AVCaptureDevice *videoDevice = [[self class] deviceWithMediaType:AVMediaTypeVideo preferringPosition:preferredPosition];
        AVCaptureDeviceInput *videoDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:videoDevice error:nil];

        [self.session beginConfiguration];

        // Remove the existing device input first, since using the front and back camera simultaneously is not supported.
        [self.session removeInput:self.videoDeviceInput];

        if ([self.session canAddInput:videoDeviceInput]) {
            [[NSNotificationCenter defaultCenter] removeObserver:self name:AVCaptureDeviceSubjectAreaDidChangeNotification object:currentVideoDevice];

            [[self class] setFlashMode:AVCaptureFlashModeAuto forDevice:videoDevice];
            [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(subjectAreaDidChange:) name:AVCaptureDeviceSubjectAreaDidChangeNotification object:videoDevice];

            [self.session addInput:videoDeviceInput];
            self.session.sessionPreset = [PLHKMediaRecorderTools AVCaptureSessionPresetConfigByMachineModel];
            self.videoDeviceInput = videoDeviceInput;
            self.videoDevice = videoDevice;
        } else {
            [self.session addInput:self.videoDeviceInput];
        }

        AVCaptureConnection *connection = [self.movieFileOutput connectionWithMediaType:AVMediaTypeVideo];
        if (connection.isVideoStabilizationSupported && [[[UIDevice currentDevice] systemVersion] integerValue] >= 8.0) {
            connection.preferredVideoStabilizationMode = AVCaptureVideoStabilizationModeAuto;
        }

        [self.session commitConfiguration];

        dispatch_async(dispatch_get_main_queue(), ^{
            if (self.videoDevice.exposureMode == AVCaptureExposureModeCustom) {
                _recordMode = HKRecordModeNight;
            } else {
                _recordMode = HKRecordModeAuto;
            }
            if (self.delegate != nil && [self.delegate conformsToProtocol:@protocol(PLHKMediaRecorderDelegate)] && [self.delegate respondsToSelector:@selector(recorder:didFinishRecordingToOutputFileAtURL:)]) {
                [self.delegate recorder:self didFinishSwitchCamara:self.videoDevice.position];
            }
        });
    });
}
- (void)setVideoTimeScale:(CGFloat)timeScale
{
    if (self.isRecording) {
        [self pause];
    }
    _currentTimeScale = timeScale;
}
- (void)focusAndExposeTap:(UIGestureRecognizer *)gestureRecognizer
{
    CGPoint devicePoint = [(AVCaptureVideoPreviewLayer *) self.previewView.layer captureDevicePointOfInterestForPoint:[gestureRecognizer locationInView:gestureRecognizer.view]];
    [self focusWithMode:AVCaptureFocusModeContinuousAutoFocus exposeWithMode:self.videoDevice.exposureMode atDevicePoint:devicePoint monitorSubjectAreaChange:YES];
}
//- (void)changeExposureMode:(AVCaptureExposureMode)captureExposureMode
//{
//    AVCaptureExposureMode mode = captureExposureMode;
//    NSError *error = nil;
//    if (self.videoDevice.exposureMode == captureExposureMode) {
//        return;
//    }
//    if ( [self.videoDevice lockForConfiguration:&error] ) {
//        if ( [self.videoDevice isExposureModeSupported:mode] ) {
//            self.videoDevice.exposureMode = mode;
//            if (mode == AVCaptureExposureModeCustom) {
//                [HUDMessagePoster postTextString:@"如果拍摄环境光线弱，可以试一下双击屏幕喔！"];
//                [self openNightMode];
//            }
//        }
//        else {
//            //曝光模式不支持
//        }
//        [self.videoDevice unlockForConfiguration];
//    }
//    else {
//        NSLog( @"Could not lock device for configuration: %@", error );
//    }
//}

- (BOOL)isSupportTorch
{
    return [self.videoDeviceInput.device hasFlash];
}

- (void)setIsTorchOn:(BOOL)isTorchOn
{
    _isTorchOn = isTorchOn;
    if (!_isTorchSupported) {
        return;
    }

    AVCaptureTorchMode torchMode;
    if (isTorchOn) {
        torchMode = AVCaptureTorchModeOn;
    } else {
        torchMode = AVCaptureTorchModeOff;
    }

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
        [device lockForConfiguration:nil];
        [device setTorchMode:torchMode];
        [device unlockForConfiguration];
    });
}

- (void)openNightMode
{
    NSError *error = nil;
    if ([self.videoDevice lockForConfiguration:&error]) {
        if ([self.videoDevice isExposureModeSupported:AVCaptureExposureModeContinuousAutoExposure]) {
            self.videoDevice.exposureMode = AVCaptureExposureModeContinuousAutoExposure;
        } else {
            //曝光模式不支持
        }
        [self.videoDevice unlockForConfiguration];
    } else {
        NSLog(@"Could not lock device for configuration: %@", error);
    }
}
- (void)closeNightMode
{
    NSError *error = nil;
    if ([self.videoDevice lockForConfiguration:&error]) {
        if ([self.videoDevice isExposureModeSupported:AVCaptureExposureModeContinuousAutoExposure]) {
            self.videoDevice.exposureMode = AVCaptureExposureModeContinuousAutoExposure;
        } else {
            //曝光模式不支持
        }
        [self.videoDevice unlockForConfiguration];
    } else {
        NSLog(@"Could not lock device for configuration: %@", error);
    }
}
- (BOOL)isReadyToRecord
{
    return !self.movieFileOutput.isRecording;
}
#pragma mark - AVCaptureFileOutputRecordingDelegate
- (void)captureOutput:(AVCaptureFileOutput *)captureOutput didStartRecordingToOutputFileAtURL:(NSURL *)fileURL fromConnections:(NSArray *)connections
{
    NSLog(@".......didStartRecordingToOutpu¡tFileAtURL%@", @([[NSDate date] timeIntervalSince1970]));
    if (self.delegate != nil && [self.delegate conformsToProtocol:@protocol(PLHKMediaRecorderDelegate)] && [self.delegate respondsToSelector:@selector(recorder:didStartRecordingToOutputFileAtURL:)]) {
        [self.delegate recorder:self didStartRecordingToOutputFileAtURL:fileURL];
    }
    [self startCountDurTimer];
    NSLog(@"开始录制");
}
- (void)captureOutput:(AVCaptureFileOutput *)captureOutput didFinishRecordingToOutputFileAtURL:(NSURL *)outputFileURL fromConnections:(NSArray *)connections error:(NSError *)error
{
    [self stopCountDurTimer];
    if (error) {
        //如果当前的录制失败了
        if (error.code == AVErrorDiskFull) {
            if (self.delegate != nil && [self.delegate conformsToProtocol:@protocol(PLHKMediaRecorderDelegate)] && [self.delegate respondsToSelector:@selector(recorder:didFailedRecordVideo:)]) {
                [self.delegate recorder:self didFailedRecordVideo:error];
            }
            return;
        }
        if ([error.userInfo[AVErrorRecordingSuccessfullyFinishedKey] boolValue] == NO) {
            if (self.delegate != nil && [self.delegate conformsToProtocol:@protocol(PLHKMediaRecorderDelegate)] && [self.delegate respondsToSelector:@selector(recorder:didFailedRecordVideo:)]) {
                [self.delegate recorder:self didFailedRecordVideo:error];
            }
            return;
        }
    }

    AVCaptureDevice *currentVideoDevice = self.videoDeviceInput.device;
    AVCaptureDevicePosition currentPosition = currentVideoDevice.position;
    [self.segments addObject:outputFileURL];
    [self.timeScaleArray addObject:@(self.currentTimeScale)];
    [self.segmentsCamaraPositionArray addObject:@(currentPosition)];
    NSLog(@"添加完当前拍摄段视频的信息，包括路径，timescale，镜头位置");

    if (self.delegate != nil && [self.delegate conformsToProtocol:@protocol(PLHKMediaRecorderDelegate)] && [self.delegate respondsToSelector:@selector(recorder:didFinishRecordingToOutputFileAtURL:)]) {
        [self.delegate recorder:self didFinishRecordingToOutputFileAtURL:outputFileURL];
    }
    if (self.delegate != nil && [self.delegate conformsToProtocol:@protocol(PLHKMediaRecorderDelegate)] && [self.delegate respondsToSelector:@selector(recorderDidChangedToPauseRecordStatus:)]) {
        [self.delegate recorderDidChangedToPauseRecordStatus:self];
    }
}
#pragma mark applicationDidBecomeActiveNotification
- (void)applicationDidBecomeActiveNotification:(NSNotification *)notification
{
    if (self.isNeedToRestartRunningSession) {
        [self startRunning];
    }
}
@end

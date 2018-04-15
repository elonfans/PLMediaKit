//
//  PLVideoRecorderVC.m
//  QiuBai
//
//  Created by 小飞 刘 on 14/12/23.
//  Copyright (c) 2014年 Less Everything. All rights reserved.
//

#import "PLVideoRecorderVC.h"
#import "PLVideoRecorderHelper.h"
#import "AVPlayer+SnapShot.h"

#import "PLSDAVAssetExportSession.h"
#import "POP.h"

#import "PLHKMediaRecorder.h"
//#import "CameraAuthorizationRequestManager.h"
#import "UIImage+PLKIAdditions.h"
//#import "UIColor+HexString.h"
#import "PLHKMediaRecorderTools.h"
#import <VideoToolbox/VideoToolbox.h>
//#import <ReactiveCocoa.h>

#import <AVFoundation/AVFoundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <CoreMedia/CoreMedia.h>
#import <QuartzCore/QuartzCore.h>
#import "UIView+Extension.h"
#import "Constant.h"

@interface PLVideoRecorderVC () <PLHKMediaRecorderDelegate>

// new recorder
@property (strong, nonatomic) PLHKMediaRecorder *mediaRecorder;

// recorder
@property (strong, nonatomic) AVPlayer *player; // video preview
@property (strong, nonatomic) AVPlayerLayer *playerLayer;
@property (strong, nonatomic) NSURL *videoOutputFileURL;
@property (strong, nonatomic) NSURL *videoEncodedFileURL;
@property (strong, nonatomic) NSString *videoEncodedFilePath;

@property (nonatomic, strong) UIView *progressView;
@property (strong, nonatomic) PLSDAVAssetExportSession *encoder;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *topAreaConstraints;

// ui
@property (weak, nonatomic) IBOutlet UIButton *backBtn;                        // 关闭按钮
@property (weak, nonatomic) IBOutlet UIButton *torchBtn;                       // 闪光灯开关
@property (weak, nonatomic) IBOutlet UIButton *switchBtn;                      // 摄像头切换按钮
@property (weak, nonatomic) IBOutlet UIButton *videoPlayBtn;                   // 预览播放按钮
@property (weak, nonatomic) IBOutlet UIView *preView;                          // 视频预览
@property (weak, nonatomic) IBOutlet UIButton *videoRecorderBtn;               // 拍摄按钮
@property (weak, nonatomic) IBOutlet UIImageView *videoRecorderShineImageView; // 呼吸效果view
@property (weak, nonatomic) IBOutlet UIImageView *videoRecorderFocusImageView; // 视频拍摄聚焦view
@property (weak, nonatomic) IBOutlet UIButton *videoDeleteBtn;                 // 删除视频按钮
@property (weak, nonatomic) IBOutlet UIButton *videoRecorderFinishedBtn;       // 拍摄完成按钮
@property (weak, nonatomic) IBOutlet UIImageView *videoEncodeLoadingImageView; // 处理中旋转动画view
@property (weak, nonatomic) IBOutlet UIView *videoEncodeMaskView;              // 水印view
@property (weak, nonatomic) IBOutlet UILabel *videoEncodeLoadingLabel;         // “视频生成中。。。” 提示view
@property (weak, nonatomic) IBOutlet UIImageView *videoWaterMaskImageView;     // 水印图片view

// gesture
@property (strong, nonatomic) UITapGestureRecognizer *tapToFocusGesture; // 聚焦点击手势
@property (strong, nonatomic) UITapGestureRecognizer *preViewBtnGesture; // 预览视频点击播放手势

// tip Bubble 按住录像，视频不能少于3秒
@property (weak, nonatomic) IBOutlet UIView *videoFirstTipBubbleView;                         // 第一次教育气泡 “按住录像，视频不能少于3秒”
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *videoFirstTipBubbleViewConstrainTop; // 教育气泡位置
@property (weak, nonatomic) IBOutlet UILabel *videoFirstTipBubbleRectangleLabel;              // 教育气泡的文本
@property (weak, nonatomic) IBOutlet UIImageView *videoFirstTipBubbleTritangleImageView;      // 教育气泡的背景

// 视频长度不能少于3s
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *videoLessThan3SecondsTipBubbleViewLeft;    // 视频长度不能少于3s的提示，位置
@property (weak, nonatomic) IBOutlet UIView *videoLessThan3SecondsTipBubbleView;                    // 视频长度不能少于3s的提示view
@property (weak, nonatomic) IBOutlet UILabel *videoLessThan3SecondsTipBubbleRectangleLabel;         // 视频长度不能少于3s的提示，文本
@property (weak, nonatomic) IBOutlet UIImageView *videoLessThan3SecondsTipBubbleTritangleImageView; // 视频长度不能少于3s的提示，北京

// others
@property (nonatomic) BOOL initalized;
@property (nonatomic) BOOL isMoreThanMaxSeconds;
@property (nonatomic) CGFloat videoCurrentDuration; // 当前进度
@property (assign, nonatomic) CGRect disRect;       // 消失动画辅助属性

//@property (nonatomic, strong) CameraAuthorizationRequestManager *cameraAuthorizationManager;
@property (nonatomic, strong) NSMutableArray *segmentLogs;

@property (nonatomic) BOOL isPreparingToDeleteLastSegment; // 准备删除最后一个片段

@property (nonatomic) CFTimeInterval totalVideoDuration;
@property (nonatomic) CFTimeInterval lastCPUT;
@property (strong, nonatomic) UIImageView *videoLastFrameImageView;
@property (strong, nonatomic) NSMutableArray *timesegArray;

@end

@implementation PLVideoRecorderVC

- (void)dealloc
{
    NSLog(@"%s", __func__);
    [self removeObserver:self forKeyPath:@"player.rate"];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    self.player = nil;
    self.mediaRecorder = nil;
}

#pragma mark - Life Cycle
- (void)viewDidLoad
{
    NSLog(@"%s", __func__);

    [super viewDidLoad];

    self.view.frame = [[UIScreen mainScreen] bounds];
    [self.view setNeedsLayout];
    [self.view layoutIfNeeded];

    if (_initalized) {
        return;
    }

    // add player Oberver
    [self addObserver:self forKeyPath:@"player.rate" options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld context:nil];

    // add Notification
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(dissmissVC) name:@"dismissPLVideoRecorderVCWhenCropVideoFinished" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillResignActive:) name:UIApplicationWillResignActiveNotification object:nil];

    // init Video Recorder
    [self initRecorder];

    // createViews
    [self createViews];

    self.initalized = YES;
}

- (void)viewWillAppear:(BOOL)animated
{
    NSLog(@"%s", __func__);
    [super viewWillAppear:animated];

    [self.mediaRecorder startRunning];
    [self.navigationController setNavigationBarHidden:YES animated:animated];
}

- (void)viewDidAppear:(BOOL)animated
{
    NSLog(@"%s", __func__);
    [super viewDidAppear:animated];

    if ([PLVideoRecorderHelper onlyShowForTheFirstTimeForKey:@"PLVideoRecorderVC_FirstTipBubbleViewJump"]) {
        [self videoFirstTipBubbleJump];
    }

    [self setApplicationStatusBarHidden:YES];
}

- (void)viewSafeAreaInsetsDidChange
{
    [super viewSafeAreaInsetsDidChange];
    self.topAreaConstraints.constant = VIEWSAFEAREAINSETS(self.view).top;
}

- (void)viewWillDisappear:(BOOL)animated
{
    NSLog(@"%s", __func__);
    [super viewWillDisappear:animated];
    [self.player pause];
    [self setApplicationStatusBarHidden:NO];
    [self.navigationController setNavigationBarHidden:NO animated:animated];
}

- (void)viewDidDisappear:(BOOL)animated
{
    NSLog(@"%s", __func__);
    [super viewDidDisappear:animated];
    [self.mediaRecorder stopRunning];
}

- (void)setApplicationStatusBarHidden:(BOOL)hidden
{
    NSLog(@"%s", __func__);
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= MP_IOS_3_2
    if ([UIApplication instancesRespondToSelector:@selector(setStatusBarHidden:withAnimation:)]) {
        // Hiding the status bar should use a fade effect.
        // Displaying the status bar should use no animation.
        UIStatusBarAnimation animation = UIStatusBarAnimationNone;
        [[UIApplication sharedApplication] setStatusBarHidden:hidden withAnimation:animation];
        return;
    }
#endif

    [[UIApplication sharedApplication] setStatusBarHidden:hidden];
}

// confirm 之后的调用
- (void)disappearWithAnimationEndRect:(CGRect)rect image:(UIImage *)image
{
    NSLog(@"%s", __func__);
    self.disRect = rect;

    [self dismissViewControllerAnimated:NO completion:nil];

    UIImageView *imageView = [[UIImageView alloc] initWithFrame:_preView.frame];
    imageView.image = image;
    UIView *window = [UIApplication sharedApplication].keyWindow;
    [window addSubview:imageView];

    __weak typeof(self) weakSelf = self;
    [UIView animateWithDuration:0.35
        delay:0.0
        options:UIViewAnimationOptionTransitionNone
        animations:^{
            imageView.frame = weakSelf.disRect;
        }
        completion:^(BOOL finished) {
            if (finished) {
                [imageView removeFromSuperview];
            }
        }];
}

- (NSMutableArray *)segmentLogs
{
    NSLog(@"%s", __func__);
    if (!_segmentLogs) {
        _segmentLogs = [NSMutableArray array];
    }
    return _segmentLogs;
}

- (NSMutableArray *)timesegArray
{
    if (!_timesegArray) {
        _timesegArray = [NSMutableArray array];
    }
    return _timesegArray;
}

#pragma mark - Main method
- (void)focusTap:(UITapGestureRecognizer *)tapGesture
{
    NSLog(@"%s", __func__);
    CGPoint focusPoint = [tapGesture locationInView:[tapGesture view]];
    [self.mediaRecorder focusAndExposeTap:tapGesture];
    self.videoRecorderFocusImageView.hidden = NO;
    self.videoRecorderFocusImageView.center = focusPoint;
    [self videoRecorderFocusAnimation];
}

- (void)configRecorder
{
    NSLog(@"%s", __func__);
    [self.mediaRecorder setVideoTimeScale:1.0];
    self.mediaRecorder.delegate = (id) self;
    self.mediaRecorder.previewView.frame = self.preView.bounds;
    [self.preView insertSubview:self.mediaRecorder.previewView atIndex:0];
    self.mediaRecorder.previewView.translatesAutoresizingMaskIntoConstraints = NO;
    UIView *preview = self.mediaRecorder.previewView;
    [self.preView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-0-[preview]-0-|" options:0 metrics:nil views:NSDictionaryOfVariableBindings(preview)]];
    [self.preView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-0-[preview]-0-|" options:0 metrics:nil views:NSDictionaryOfVariableBindings(preview)]];
}

- (void)initRecorder
{
    NSLog(@"%s", __func__);
    self.mediaRecorder = [[PLHKMediaRecorder alloc] init];
    [self.preView addSubview:self.mediaRecorder.previewView];
    
    AVAuthorizationStatus videoAuthStatus = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
    if (videoAuthStatus == AVAuthorizationStatusNotDetermined) {// 未询问用户是否授权
        [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^(BOOL granted) {
            if (granted) {// 用户同意授权
                [self start];
            }
        }];
    } else if (videoAuthStatus == AVAuthorizationStatusRestricted || videoAuthStatus == AVAuthorizationStatusDenied) {// 未授权
        [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^(BOOL granted) {
            if (granted){// 用户同意授权
                [self start];
            }
        }];
    } else { // 已授权
        [self start];
    }
}

- (void)start
{
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        [weakSelf configRecorder];
        [weakSelf.mediaRecorder startRunning];
    });
}

- (void)createViews
{
    NSLog(@"%s", __func__);
    self.videoFirstTipBubbleTritangleImageView.transform = CGAffineTransformMakeRotation(M_PI_4);
    if ([PLVideoRecorderHelper onlyShowForTheFirstTimeForKey:@"PLVideoRecorderVC_FirstTipBubbleView"]) {
        self.videoFirstTipBubbleRectangleLabel.layer.masksToBounds = YES;
        self.videoFirstTipBubbleRectangleLabel.clipsToBounds = YES;
        self.videoFirstTipBubbleRectangleLabel.layer.cornerRadius = 5;
        self.videoFirstTipBubbleViewConstrainTop.constant = CGRectGetHeight(self.videoFirstTipBubbleView.frame) + 8;
        [self.videoFirstTipBubbleView setNeedsLayout];
        [self.videoFirstTipBubbleView layoutIfNeeded];
        self.videoFirstTipBubbleView.hidden = YES;
    }
    self.videoLessThan3SecondsTipBubbleTritangleImageView.transform = CGAffineTransformMakeRotation(M_PI_4);
    if ([PLVideoRecorderHelper onlyShowForTheFirstTimeForKey:@"PLVideoRecorderVC_LessThan3SecondsBubbleView"]) {
        self.videoLessThan3SecondsTipBubbleViewLeft.constant = CGRectGetWidth(self.view.frame) * 3 / MAX_VIDEO_DUR - CGRectGetWidth(self.videoLessThan3SecondsTipBubbleView.frame) / 2;
        self.videoLessThan3SecondsTipBubbleRectangleLabel.layer.masksToBounds = YES;
        self.videoLessThan3SecondsTipBubbleView.clipsToBounds = YES;
        self.videoLessThan3SecondsTipBubbleRectangleLabel.layer.cornerRadius = 5;
    }

    // progress
    CGRect preViewRect = self.preView.frame;

    self.progressView = [[UIView alloc] initWithFrame:CGRectMake(0, preViewRect.origin.y + CGRectGetHeight(preViewRect) + KOSStatusBarHeight, CGRectGetWidth(preViewRect), 5)];
    self.progressView.backgroundColor = [UIColor colorWithRed:255 / 255.0 green:160 / 255.0 blue:21 / 255.0 alpha:1];
    self.progressView.tag = 1111;

    // progressTagView
    UIView *progressTagView = [[UIView alloc] initWithFrame:CGRectMake(CGRectGetWidth(self.progressView.frame) * ((CGFloat) MIN_VIDEO_DUR / MAX_VIDEO_DUR), CGRectGetMinY(self.progressView.frame), 1, CGRectGetHeight(self.progressView.frame))];
    progressTagView.backgroundColor = [UIColor colorWithRed:255 / 255.0 green:160 / 255.0 blue:21 / 255.0 alpha:1];
    // 时长改为3分钟，去掉最小标示
    [self.view addSubview:progressTagView];
    [self.view addSubview:self.progressView];
    
    self.progressView.frame = CGRectMake(self.progressView.frame.origin.x, self.progressView.frame.origin.y, 0, self.progressView.frame.size.height);

    self.videoLastFrameImageView = [[UIImageView alloc] initWithFrame:self.preView.bounds];
    [self.preView addSubview:self.videoLastFrameImageView];
    self.videoLastFrameImageView.userInteractionEnabled = NO;
    self.videoLastFrameImageView.backgroundColor = [UIColor clearColor];
    self.videoLastFrameImageView.contentMode = UIViewContentModeScaleAspectFill;
    self.videoLastFrameImageView.opaque = YES;

    // other Btns
    [self.backBtn setImage:[UIImage imageNamed:@"resource.bundle/video_close@2x.png"] forState:UIControlStateNormal];
    [self.torchBtn setImage:[UIImage imageNamed:@"resource.bundle/video_flash@2x.png"] forState:UIControlStateNormal];
    [self.torchBtn setImage:[UIImage imageNamed:@"resource.bundle/video_flash_on@2x.png"] forState:UIControlStateSelected];
    [self.switchBtn setImage:[UIImage imageNamed:@"resource.bundle/video_camera@2x.png"] forState:UIControlStateNormal];
    [self.videoRecorderBtn setImage:[UIImage imageNamed:@"resource.bundle/video_recorder@2x.png"] forState:UIControlStateNormal];
    [self.videoPlayBtn setImage:[UIImage imageNamed:@"resource.bundle/video_play@3x.png"]forState:UIControlStateNormal];
    [self.videoDeleteBtn setImage:[UIImage imageNamed:@"resource.bundle/video_record_del_nor@3x.png"] forState:UIControlStateNormal];
    [self.videoDeleteBtn setImage:[UIImage imageNamed:@"resource.bundle/video_record_del_nor@3x.png"] forState:UIControlStateDisabled];
    [self.videoRecorderFinishedBtn setImage:[UIImage imageNamed:@"resource.bundle/video_record_done_enable@3x.png"] forState:UIControlStateNormal];
    [self.videoRecorderFinishedBtn setImage:[UIImage imageNamed:@"resource.bundle/video_record_done_disable@3x.png"] forState:UIControlStateDisabled];
    [self.videoRecorderShineImageView setImage:[UIImage imageNamed:@"resource.bundle/video_recorder_shine@3x.png"]];
    self.videoRecorderShineImageView.hidden = YES;

    // torch btn hidden when launch on ipod touch
    if (![self.mediaRecorder isTorchSupported]) {
        self.torchBtn.hidden = YES;
    }

    // videoRecorderFocusImageView
    self.videoRecorderFocusImageView.layer.zPosition = 10;
    [self.videoRecorderFocusImageView setImage:[UIImage imageNamed:@"resource.bundle/video_recorder_focus@3x.png"]];
    self.videoRecorderFocusImageView.hidden = YES;

    // change border when btn is highlighted
    self.videoDeleteBtn.adjustsImageWhenHighlighted = NO;
    self.videoRecorderFinishedBtn.adjustsImageWhenHighlighted = NO;

    // waterMask
    self.videoWaterMaskImageView.layer.zPosition = 2;
    [self.videoWaterMaskImageView setImage:[UIImage imageNamed:@"resource.bundle/videoWaterMask@3x.png"]];
    self.videoWaterMaskImageView.hidden = YES;

    // videoEncode
    self.videoEncodeLoadingImageView.layer.zPosition = 4;
    self.videoEncodeLoadingImageView.hidden = YES;
    [self.videoEncodeLoadingImageView setImage:[UIImage imageNamed:@"resource.bundle/videoEncodeLoading@2x.png"]];
    self.videoEncodeLoadingLabel.layer.zPosition = 4;
    self.videoEncodeLoadingLabel.hidden = YES;

    // videoEncodeMask
    self.videoEncodeMaskView.layer.zPosition = 6;
    self.videoEncodeMaskView.alpha = 0.5;
    [self.videoEncodeMaskView setBackgroundColor:[UIColor blackColor]];
    self.videoEncodeMaskView.hidden = YES;

    // hide these Btns until start recorder
    self.videoPlayBtn.layer.zPosition = 4;
    self.videoPlayBtn.hidden = YES;
    self.videoDeleteBtn.hidden = YES;
    self.videoRecorderFinishedBtn.hidden = YES;

    // gesture
    self.tapToFocusGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(focusTap:)];
    [self.preView addGestureRecognizer:self.tapToFocusGesture];

    // video operate Btn disabled until start recorder
    self.videoDeleteBtn.enabled = NO;
    self.videoRecorderFinishedBtn.enabled = NO;
}

- (void)preViewPressed
{
    NSLog(@"%s", __func__);
    if (self.player.rate == 0) {
        [self.player play];
    } else {
        [self.player pause];
    }
}

- (void)preViewRecorderedVideo
{
    NSLog(@"%s", __func__);
    // player
    self.player = [AVPlayer playerWithURL:self.videoOutputFileURL];
    self.player.actionAtItemEnd = AVPlayerActionAtItemEndNone;
    self.playerLayer = [AVPlayerLayer layer];
    [self.playerLayer setPlayer:self.player];
    [self.playerLayer setFrame:self.preView.bounds];
    [self.playerLayer setVideoGravity:AVLayerVideoGravityResizeAspectFill];
    [self.preView.layer addSublayer:self.playerLayer];

    // gesture
    [self.preView removeGestureRecognizer:self.tapToFocusGesture];
    self.preViewBtnGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(preViewPressed)];
    [self.preView addGestureRecognizer:self.preViewBtnGesture];

    // add Notification
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playItemDidReachEnd:) name:AVPlayerItemDidPlayToEndTimeNotification object:nil];

    // play
    [self.player play];
}

#pragma mark - Video Duration Methods
- (void)setTotalVideoDuration:(CFTimeInterval)totalVideoDuration
{
    NSLog(@"++++++++ %f", totalVideoDuration);
    _totalVideoDuration = totalVideoDuration;
}

- (void)onRecorderStart
{
    self.lastCPUT = CACurrentMediaTime();
}

- (void)onRecorderPause
{
    NSTimeInterval duration = CACurrentMediaTime() - self.lastCPUT;
    [self.timesegArray addObject:@(duration)];
    self.lastCPUT = CACurrentMediaTime();
    self.totalVideoDuration += duration;
}

- (void)onRecorderStop
{
    NSTimeInterval duration = CACurrentMediaTime() - self.lastCPUT;
    [self.timesegArray addObject:@(duration)];
    self.lastCPUT = CACurrentMediaTime();
    self.totalVideoDuration += duration;
}

#pragma mark - Outlet
- (IBAction)onRecorderBtnTouchDown:(id)sender
{
    if (self.isPreparingToDeleteLastSegment) {
        self.isPreparingToDeleteLastSegment = NO;
        [self removeWillDeletedSegmentProgressView];
    }

    if ([PLVideoRecorderHelper onlyShowForTheFirstTimeForKey:@"PLVideoRecorderVC_hideFirstTipBubbleView"]) {
        self.videoFirstTipBubbleView.hidden = YES;
    }

    [self videoRecorderShineAnimationStart];
    [self.mediaRecorder startRecording];
    if (self.mediaRecorder.segments.count == 0) {
        self.totalVideoDuration = 0;
    }
    [self onRecorderStart];

    self.videoDeleteBtn.enabled = NO;
    self.videoRecorderFinishedBtn.userInteractionEnabled = NO;
}

- (IBAction)onRecorderBtnTouchUp:(id)sender
{
    NSLog(@"%s", __func__);
    [self videoRecorderShineAnimationStop];
    if (!self.mediaRecorder.isRecording) {
        return;
    }

    if (self.totalVideoDuration > MIN_VIDEO_DUR) {
        self.videoRecorderFinishedBtn.enabled = YES;
    }
    [self.mediaRecorder pause];
    [self.videoDeleteBtn setImage:[UIImage imageNamed:@"resource.bundle/video_record_del_nor@3x.png"] forState:UIControlStateNormal];
    self.isPreparingToDeleteLastSegment = NO;
    [self onRecorderPause];

    self.videoDeleteBtn.enabled = YES;
    self.videoRecorderFinishedBtn.userInteractionEnabled = YES;
}

- (void)recorderButtonTouchLessThanOneSecond
{
    NSLog(@"%s", __func__);
    self.videoRecorderBtn.hidden = NO;
    self.videoRecorderBtn.userInteractionEnabled = YES;
}

- (IBAction)onBackBtnPressed:(id)sender
{
    NSLog(@"%s", __func__);
    [self.player pause];
    [self.mediaRecorder stopRunning];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (_recordVCDismssCallback) {
            _recordVCDismssCallback();
        } else {
            [self dismissViewControllerAnimated:YES completion:nil];
        }
    });
}
- (IBAction)onTorchBtnPressed:(id)sender
{
    NSLog(@"%s", __func__);
    // TODO: 开关闪光灯
    if (self.mediaRecorder.isTorchOn) {
        [self.mediaRecorder closeNightMode];
    } else {
        [self.mediaRecorder openNightMode];
    }
    self.torchBtn.selected = !self.torchBtn.selected;
    self.mediaRecorder.isTorchOn = self.torchBtn.selected;
}

- (IBAction)onSwitchBtnPressed:(id)sender
{
    NSLog(@"%s", __func__);
    [self.mediaRecorder switchCamara];
    if ([self.mediaRecorder isTorchSupported]) {
        if (self.mediaRecorder.isUsingFrontCamera) {
            self.torchBtn.hidden = YES;
        } else {
            self.torchBtn.hidden = NO;
        }
    }
    self.torchBtn.selected = NO;
}

- (IBAction)videoPlayBtnPressed:(id)sender
{
    NSLog(@"%s", __func__);
    [self preViewPressed];
}

- (IBAction)onVideoDeleteBtnPress:(id)sender
{
    NSLog(@"%s", __func__);
    // 判断是不是要删除片段，和删除片段选中状态
    if (self.isPreparingToDeleteLastSegment) {
        [self.mediaRecorder deleteCurrentAsset];
    } else {
        [self showWillDeletedSegmentProgressView];
        self.isPreparingToDeleteLastSegment = YES;
        [self.videoDeleteBtn setImage:[UIImage imageNamed:@"resource.bundle/video_record_del_ready@3x.png"] forState:UIControlStateNormal];
    }
}

- (IBAction)onVideoRecorderFinishedBtnPressed:(id)sender
{
    NSLog(@"%s", __func__);

    // ui
    [self.player pause];
    self.videoPlayBtn.hidden = YES;

    self.videoEncodeMaskView.hidden = YES;
    self.videoDeleteBtn.userInteractionEnabled = NO;
    self.videoRecorderFinishedBtn.userInteractionEnabled = NO;

    self.videoEncodeLoadingImageView.hidden = NO;
    self.videoEncodeLoadingLabel.hidden = NO;

    self.videoRecorderBtn.enabled = NO;
    self.videoRecorderFinishedBtn.enabled = NO;
    self.videoDeleteBtn.enabled = NO;

    // encode loading animation
    CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:@"transform.rotation.z"];
    animation.duration = ENCODELOADINGIMAGEVIEW_ANIMATION_DURATION;
    animation.fromValue = [NSNumber numberWithFloat:0.0];
    animation.toValue = [NSNumber numberWithFloat:2 * M_PI];
    animation.repeatCount = HUGE;
    [self.videoEncodeLoadingImageView.layer addAnimation:animation forKey:@"pauley"];

    // 等待合成回调
    [self.mediaRecorder stopRecording];
}

- (void)resetRescordSession
{
    NSLog(@"%s", __func__);
    dispatch_async(dispatch_get_main_queue(), ^{
        self.progressView.left = 0;
        self.progressView.width = 0;
        for (UIView *view in self.progressView.superview.subviews) {
            if (view.tag == 888 || view.tag == 999) {
                [view removeFromSuperview];
            }
        }
        self.videoLastFrameImageView.image = nil;
        self.videoRecorderFinishedBtn.hidden = YES;
        self.videoRecorderFinishedBtn.enabled = NO;
        self.videoDeleteBtn.hidden = YES;

        self.videoEncodeLoadingImageView.hidden = YES;
        self.videoEncodeLoadingLabel.hidden = YES;
        self.videoRecorderBtn.enabled = YES;
        self.videoDeleteBtn.enabled = YES;
        self.videoDeleteBtn.userInteractionEnabled = YES;
        self.videoRecorderFinishedBtn.userInteractionEnabled = YES;
    });

    // 总时间归零
    self.totalVideoDuration = 0;
    self.timesegArray = nil;

    [self.mediaRecorder resetRescordSession];
    [self.mediaRecorder startRunning];
    [self.mediaRecorder setVideoTimeScale:1.0];
}

// todo:
- (void)addSeparateLineOnProgressBar
{
    NSLog(@"%s", __func__);
    UIView *separateLineView = [[UIView alloc] initWithFrame:self.progressView.frame];
    separateLineView.tag = 888;
    separateLineView.backgroundColor = self.progressView.backgroundColor;

    dispatch_async(dispatch_get_main_queue(), ^{
        [self.progressView.superview addSubview:separateLineView];
        self.progressView.left = CGRectGetMaxX(self.progressView.frame) + 2.0f;
        self.progressView.width = 0;
    });
}

- (void)showWillDeletedSegmentProgressView
{
    NSLog(@"%s", __func__);
    UIView *view = [self.progressView.superview.subviews lastObject];

    UIView *betweenSeparateLineView = [[UIView alloc] initWithFrame:view.frame];
    betweenSeparateLineView.backgroundColor = UIColorFromRGB(0xff565e);
    betweenSeparateLineView.tag = 999;
    [self.progressView.superview addSubview:betweenSeparateLineView];
}

- (void)removeWillDeletedSegmentProgressView
{
    for (UIView *view in self.progressView.superview.subviews) {
        if (view.tag == 999) {
            [view removeFromSuperview];
        }
    }
}

- (void)recordDurationDidUpdatedWithTotalDuration:(CGFloat)totalDuration isDeleted:(BOOL)isDeleted
{
    if (totalDuration >= MAX_VIDEO_DUR) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.videoRecorderBtn.enabled = NO;
            [self onRecorderBtnTouchUp:nil];
        });
        return;
    }
    
    CGFloat percentage = totalDuration / MAX_VIDEO_DUR;
    CGFloat screenWidth = [UIScreen mainScreen].bounds.size.width;
    CGFloat __block progressWidth = percentage * screenWidth;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        self.videoRecorderFinishedBtn.enabled = YES;
        if (totalDuration <= MIN_VIDEO_DUR) {
            self.videoRecorderFinishedBtn.enabled = NO;
        }
        // 删除片段
        if (progressWidth > self.progressView.width || isDeleted) {
            if (isDeleted) {
                [self removeWillDeletedSegmentProgressView];
                if (self.progressView.superview.subviews.lastObject.tag == 888) {
                    [self.progressView.superview.subviews.lastObject removeFromSuperview];
                }
                [self.videoDeleteBtn setImage:[UIImage imageNamed:@"resource.bundle/video_record_del_nor@3x.png"] forState:UIControlStateNormal];
                self.videoDeleteBtn.hidden = self.mediaRecorder.segments.count == 0;
                self.isPreparingToDeleteLastSegment = NO;
                UIView *view = self.progressView.superview.subviews.lastObject;
                progressWidth = CGRectGetMaxX(view.frame);
                self.progressView.left = progressWidth + 2.0f;
                if (self.mediaRecorder.segments.count == 0) {
                    self.progressView.left = 0;
                }
                self.progressView.width = 0;
            } else {
                progressWidth = progressWidth - CGRectGetMinX(self.progressView.frame);
                self.progressView.width = progressWidth;
            }
        }
    });
}

#pragma mark - video upload info stat
- (void)logViedoClipInfo4StatWithRecorder:(PLHKMediaRecorder *)recorder fileURL:(NSURL *)fileURL
{
    NSLog(@"%s", __func__);

    AVCaptureDevicePosition devicePosition = recorder.videoDevice.position;
    AVAsset *asset = [AVAsset assetWithURL:fileURL];
    CGFloat currentSegmentDuration = recorder.currentTimeScale * CMTimeGetSeconds([asset duration]);
    CGFloat speedScale = recorder.currentTimeScale;

    [self.segmentLogs addObject:@{ @"kDevicePosition" : @(devicePosition),
                                   @"kSegmentDuration" : @(currentSegmentDuration),
                                   @"kSpeedScale" : @(speedScale) }];
}

#pragma mark - KVO
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    NSLog(@"%s", __func__);
    if (((PLVideoRecorderVC *) object).player != self.player) {
        return;
    }

    if (change[@"old"] != [NSNull null] && change[@"new"] != [NSNull null]) {
        if ([change[@"old"] integerValue] == 0 && [change[@"new"] integerValue] == 0) {
            return;
        }
    }

    if (self.player.rate == 0) {
        self.videoPlayBtn.hidden = NO;
    } else {
        self.videoPlayBtn.hidden = YES;
    }
}

#pragma mark - PLHKMediaRecorderDelegate
- (void)recorder:(PLHKMediaRecorder *)recorder didFailedRecordVideo:(NSError *)error
{
    NSLog(@"%s", __func__);
    [self resetRescordSession];
}

- (void)recorder:(PLHKMediaRecorder *)recorder didConfigurationAsset:(AVMutableComposition *)composition withVideoComposition:(AVMutableVideoComposition *)videoComposition
{
    NSLog(@"%s", __func__);
    self.videoEncodedFilePath = [PLVideoRecorderHelper getFilePathByTime];
    self.videoEncodedFileURL = [NSURL fileURLWithPath:[[NSHomeDirectory() stringByAppendingPathComponent:@"Documents"] stringByAppendingPathComponent:self.videoEncodedFilePath]];
    self.encoder = [[PLSDAVAssetExportSession alloc] initWithAsset:composition];
    self.encoder.videoComposition = videoComposition;
    self.encoder.timeRange = CMTimeRangeMake(kCMTimeZero, composition.duration);
    self.encoder.outputFileType = AVFileTypeMPEG4;
    self.encoder.outputURL = self.videoEncodedFileURL;
    self.encoder.shouldOptimizeForNetworkUse = YES;
    self.encoder.videoInputSettings = @{
        (id) kCVPixelBufferPixelFormatTypeKey : @(kCVPixelFormatType_32BGRA),
    };

    self.encoder.videoSettings = @{
        AVVideoCodecKey : AVVideoCodecH264,
        AVVideoWidthKey : @([PLHKMediaRecorderTools videoSizeConfigByMachineModel].width),
        AVVideoHeightKey : @([PLHKMediaRecorderTools videoSizeConfigByMachineModel].height),
        AVVideoScalingModeKey : AVVideoScalingModeResizeAspect, // 缩放
        AVVideoCompressionPropertiesKey : @{
            AVVideoExpectedSourceFrameRateKey : @(15),
            AVVideoMaxKeyFrameIntervalKey : @(15), // 帧率
            AVVideoAverageBitRateKey : @2000000,   // 码率
            AVVideoProfileLevelKey : AVVideoProfileLevelH264Main31,
            (NSString *) kVTCompressionPropertyKey_ColorPrimaries : (NSString *) kCMFormatDescriptionColorPrimaries_ITU_R_709_2,
            (NSString *) kVTCompressionPropertyKey_TransferFunction : (NSString *) kCMFormatDescriptionTransferFunction_ITU_R_709_2,
            (NSString *) kVTCompressionPropertyKey_YCbCrMatrix : (NSString *) kCMFormatDescriptionYCbCrMatrix_ITU_R_709_2,
        },
    };

    self.encoder.audioSettings = @{
        AVFormatIDKey : @(kAudioFormatMPEG4AAC),
        AVNumberOfChannelsKey : @2,
        AVSampleRateKey : @44100,
        AVEncoderBitRateKey : @96000,
        AVEncoderBitRateStrategyKey : AVAudioBitRateStrategy_Constant,
    };

    __weak typeof(self) weakSelf = self;
    [self.encoder exportAsynchronouslyWithCompletionHandler:^{
        UIImage *videoPreViewImage = [UIImage thumbnailImageForVideo:weakSelf.videoEncodedFileURL atTime:0.1];

        AVAsset *asset = [AVAsset assetWithURL:self.videoEncodedFileURL];

        NSLog(@"%@ %f", asset, [PLVideoRecorderHelper getFileSize:self.videoEncodedFileURL]);

        if (weakSelf.encoder.status == AVAssetExportSessionStatusCompleted) {
            dispatch_async(dispatch_get_main_queue(), ^{
                // done
                if ([_delegate respondsToSelector:@selector(onVideoSelectedWithPath:firstImg:videoOriginHash:)]) {
                    [_delegate onVideoSelectedWithPath:self.videoEncodedFilePath firstImg:videoPreViewImage videoOriginHash:nil];
                }
                CGRect rect = CGRectZero;
                if ([_delegate respondsToSelector:@selector(animateEndRect)]) {
                    rect = [_delegate animateEndRect];
                }

                [self dismissViewControllerAnimated:YES completion:nil];
            });
        }
    }];
}

- (void)recorder:(PLHKMediaRecorder *)recorder didStartRecordingToOutputFileAtURL:(NSURL *)fileURL
{
    NSLog(@"%s", __func__);
    self.videoLastFrameImageView.alpha = 0;
    self.videoDeleteBtn.hidden = NO;
    self.videoDeleteBtn.hidden = NO;
    self.videoRecorderFinishedBtn.hidden = NO;
    self.switchBtn.hidden = YES;
}

- (void)recorder:(PLHKMediaRecorder *)recorder didFinishRecordingToOutputFileAtURL:(NSURL *)outputFileURL
{
    NSLog(@"%s %@", __func__, outputFileURL);
    [self addSeparateLineOnProgressBar];
    [self logViedoClipInfo4StatWithRecorder:self.mediaRecorder fileURL:outputFileURL];
    dispatch_async(dispatch_get_main_queue(), ^{
        self.videoDeleteBtn.hidden = NO;
        self.videoDeleteBtn.enabled = YES;
        self.backBtn.hidden = NO;
        self.switchBtn.hidden = NO;

        if (self.totalVideoDuration < MIN_VIDEO_DUR) {
            if ([PLVideoRecorderHelper onlyShowForTheFirstTimeForKey:@"PLVideoRecorderVC_showLessThan3SecondsBubbleView"]) {
                self.videoLessThan3SecondsTipBubbleView.hidden = NO;
                [self videoLessThan3SecondsTipBubbleJumpAndFade];
            }
        }
    });
    AVAsset *asset = [AVAsset assetWithURL:outputFileURL];
    UIImage *image = [UIImage thumbnailImageForVideo:outputFileURL atTime:asset.duration.value];
    if ([[self.mediaRecorder.segmentsCamaraPositionArray lastObject] integerValue] == AVCaptureDevicePositionFront) {
        image = [image leftRightMirrored];
    }
    self.videoLastFrameImageView.image = image;
    self.videoLastFrameImageView.alpha = 0.3;
}
- (void)recorder:(PLHKMediaRecorder *)recorder didRecordedDuration:(CGFloat)duration totalDuration:(CGFloat)totalDuration
{
    NSLog(@"%s", __func__);
    // 总的时间进度不能依靠recoder的回调，需要自己计算
    CFTimeInterval totalVideoDuration = (CACurrentMediaTime() - self.lastCPUT) + self.totalVideoDuration;
    [self recordDurationDidUpdatedWithTotalDuration:totalVideoDuration isDeleted:NO];
}
- (void)recorder:(PLHKMediaRecorder *)recorder didFinishSwitchCamara:(AVCaptureDevicePosition)captureDevicePosition
{
    NSLog(@"%s", __func__);
    self.switchBtn.enabled = YES;
}
- (void)recorder:(PLHKMediaRecorder *)recorder didFailedConfigSegments:(NSError *)error
{
    NSLog(@"%s", __func__);
    [self resetRescordSession];
}
- (void)recorder:(PLHKMediaRecorder *)recorder willDeleteDuration:(CMTime)duration
{
    NSLog(@"%s", __func__);
    //    self.totalVideoDuration -= CMTimeGetSeconds(duration);
    if (self.timesegArray.count > 0) {
        self.totalVideoDuration -= [[self.timesegArray lastObject] doubleValue];
        [self.timesegArray removeLastObject];
    }

    if (self.mediaRecorder.segments.count == 0) {
        self.totalVideoDuration = 0;
        [self resetRescordSession];
    }

    [self.segmentLogs removeLastObject];

    [self recordDurationDidUpdatedWithTotalDuration:self.totalVideoDuration isDeleted:YES];
    if (self.mediaRecorder.segments.count >= 1) {
        AVAsset *asset = [AVAsset assetWithURL:self.mediaRecorder.segments[self.mediaRecorder.segments.count - 1]];
        UIImage *image = [UIImage thumbnailImageForVideo:[self.mediaRecorder.segments lastObject] atTime:asset.duration.value];
        if ([[self.mediaRecorder.segmentsCamaraPositionArray lastObject] integerValue] == AVCaptureDevicePositionFront) {
            image = [image leftRightMirrored];
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            self.videoLastFrameImageView.image = image;
            self.videoLastFrameImageView.alpha = 0.3;
        });
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.videoLastFrameImageView.image = nil;
        });
    }
}

- (void)recorderDidChangedToPauseRecordStatus:(PLHKMediaRecorder *)recorder
{
    NSLog(@"%s", __func__);
}

#pragma mark - Notification
- (void)playItemDidReachEnd:(NSNotification *)notification
{
    NSLog(@"%s", __func__);
    AVPlayerItem *item = [notification object];
    [item seekToTime:kCMTimeZero];
    [self.player play];
}

#pragma mark - Animations
- (POPBasicAnimation *)getVideoRecorderBtnsPOPBasicAnimationWithKeyPath:(NSString *)keyPath toValue:(id)tovalue beginTime:(CFTimeInterval)beginTime duration:(CFTimeInterval)duration
{
    NSLog(@"%s", __func__);
    POPBasicAnimation *videoRecorderBtnsPOPBasicAnimation = [POPBasicAnimation animationWithPropertyNamed:keyPath];
    videoRecorderBtnsPOPBasicAnimation.toValue = tovalue;
    videoRecorderBtnsPOPBasicAnimation.beginTime = beginTime;
    videoRecorderBtnsPOPBasicAnimation.duration = duration;
    return videoRecorderBtnsPOPBasicAnimation;
}

- (void)videoFirstTipBubbleJump
{
    CABasicAnimation *videoFirstTipBubbleAni = [CABasicAnimation animationWithKeyPath:@"position.y"];
    videoFirstTipBubbleAni.autoreverses = YES;
    videoFirstTipBubbleAni.duration = VIDEOFIRSTTIPBUBBLE_JUMP_DURATION;
    videoFirstTipBubbleAni.fromValue = [NSNumber numberWithFloat:self.videoFirstTipBubbleView.layer.position.y];
    videoFirstTipBubbleAni.toValue = [NSNumber numberWithFloat:self.videoFirstTipBubbleView.layer.position.y - 6];
    videoFirstTipBubbleAni.repeatCount = HUGE;
    videoFirstTipBubbleAni.removedOnCompletion = NO;
    videoFirstTipBubbleAni.beginTime = 0;
    videoFirstTipBubbleAni.fillMode = kCAFillModeForwards;
    [self.videoFirstTipBubbleView.layer addAnimation:videoFirstTipBubbleAni forKey:@"paulery"];
}

- (void)videoLessThan3SecondsTipBubbleJumpAndFade
{
    CABasicAnimation *videoTipBubbleAniJump = [CABasicAnimation animationWithKeyPath:@"position.y"];
    videoTipBubbleAniJump.autoreverses = YES;
    videoTipBubbleAniJump.duration = VIDEOTIPBUBBLE_JUMP_DURATION;
    videoTipBubbleAniJump.fromValue = [NSNumber numberWithFloat:self.videoLessThan3SecondsTipBubbleView.layer.position.y];
    videoTipBubbleAniJump.toValue = [NSNumber numberWithFloat:self.videoLessThan3SecondsTipBubbleView.layer.position.y - 6];
    videoTipBubbleAniJump.repeatCount = 4;
    videoTipBubbleAniJump.removedOnCompletion = NO;
    videoTipBubbleAniJump.beginTime = 0;
    videoTipBubbleAniJump.fillMode = kCAFillModeForwards;

    CABasicAnimation *videoTipBubbleAniFade = [CABasicAnimation animationWithKeyPath:@"opacity"];
    videoTipBubbleAniFade.autoreverses = YES;
    videoTipBubbleAniFade.duration = VIDEOTIPBUBBLE_JUMP_DURATION;
    videoTipBubbleAniFade.fromValue = [NSNumber numberWithFloat:1.0];
    videoTipBubbleAniFade.toValue = [NSNumber numberWithFloat:0.0];
    videoTipBubbleAniFade.repeatCount = 1;
    videoTipBubbleAniFade.removedOnCompletion = NO;
    videoTipBubbleAniFade.beginTime = VIDEOTIPBUBBLE_JUMP_DURATION * 4;
    videoTipBubbleAniFade.fillMode = kCAFillModeForwards;

    CAAnimationGroup *animationGroup = [CAAnimationGroup animation];
    animationGroup.beginTime = 0;
    animationGroup.duration = VIDEOTIPBUBBLE_JUMP_DURATION * 5;
    animationGroup.removedOnCompletion = NO;
    animationGroup.fillMode = kCAFillModeForwards;
    animationGroup.repeatCount = 1;
    animationGroup.animations = [NSArray arrayWithObjects:videoTipBubbleAniJump, videoTipBubbleAniFade, nil];

    [self.videoLessThan3SecondsTipBubbleView.layer addAnimation:animationGroup forKey:@"paulery"];
}

- (void)videoRecorderShineAnimationStart
{
    NSLog(@"%s", __func__);
    self.videoRecorderShineImageView.hidden = NO;
    CABasicAnimation *shineAnimation = [CABasicAnimation animationWithKeyPath:@"opacity"];
    shineAnimation.duration = VIDEORECORDERSHINE_DURATION;
    shineAnimation.fromValue = @(0.0);
    shineAnimation.toValue = @(1.0);
    shineAnimation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear];
    shineAnimation.autoreverses = YES;
    shineAnimation.repeatCount = HUGE;
    shineAnimation.removedOnCompletion = NO;
    shineAnimation.beginTime = 0;
    shineAnimation.fillMode = kCAFillModeForwards;
    [self.videoRecorderShineImageView.layer addAnimation:shineAnimation forKey:@"paulery"];
    [self.videoRecorderShineImageView.superview bringSubviewToFront:self.videoRecorderShineImageView];
}

- (void)videoRecorderFocusAnimation
{
    NSLog(@"%s", __func__);
    // remove original animation
    [self.videoRecorderFocusImageView.layer removeAllAnimations];

    // interactive for 3 times
    CGFloat videoRecorderFocusScale = 1.2;
    CGFloat videoRecorderFocusDuration = 0.18f;

    CABasicAnimation *scaleAnimation1 = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
    scaleAnimation1.duration = videoRecorderFocusDuration;
    scaleAnimation1.beginTime = 0;
    scaleAnimation1.fromValue = [NSNumber numberWithFloat:videoRecorderFocusScale];
    scaleAnimation1.toValue = [NSNumber numberWithFloat:1.0f];
    scaleAnimation1.autoreverses = YES;
    scaleAnimation1.repeatCount = 6;
    scaleAnimation1.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    scaleAnimation1.removedOnCompletion = NO;
    scaleAnimation1.fillMode = kCAFillModeForwards;
    [self.videoRecorderFocusImageView.layer addAnimation:scaleAnimation1 forKey:@"scaleAnimation1"];

    // scale 1 -> 0
    CABasicAnimation *scaleAnimation2 = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
    scaleAnimation2.duration = videoRecorderFocusDuration;
    scaleAnimation2.beginTime = videoRecorderFocusDuration * 6;
    scaleAnimation2.fromValue = [NSNumber numberWithFloat:1.0f];
    scaleAnimation2.toValue = [NSNumber numberWithFloat:0.0f];
    scaleAnimation2.autoreverses = NO;
    scaleAnimation2.repeatCount = 1;
    scaleAnimation2.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseIn];
    scaleAnimation2.removedOnCompletion = YES;
    scaleAnimation2.fillMode = kCAFillModeForwards;
    [self.videoRecorderFocusImageView.layer addAnimation:scaleAnimation2 forKey:@"scaleAnimation2"];

    CABasicAnimation *fadeAnimation = [CABasicAnimation animationWithKeyPath:@"opacity"];
    fadeAnimation.duration = videoRecorderFocusDuration;
    fadeAnimation.beginTime = videoRecorderFocusDuration * 6;
    fadeAnimation.fromValue = [NSNumber numberWithFloat:1.0f];
    fadeAnimation.toValue = [NSNumber numberWithFloat:0.0f];
    fadeAnimation.autoreverses = NO;
    fadeAnimation.repeatCount = 1;
    fadeAnimation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseIn];
    fadeAnimation.removedOnCompletion = YES;
    fadeAnimation.fillMode = kCAFillModeForwards;
    [self.videoRecorderFocusImageView.layer addAnimation:fadeAnimation forKey:@"fadeAnimation"];

    CAAnimationGroup *animationGroup = [CAAnimationGroup animation];
    animationGroup.duration = videoRecorderFocusDuration * 7;
    animationGroup.removedOnCompletion = NO;
    animationGroup.fillMode = kCAFillModeForwards;
    animationGroup.animations = [NSArray arrayWithObjects:scaleAnimation1, scaleAnimation2, fadeAnimation, nil];
    [self.videoRecorderFocusImageView.layer addAnimation:animationGroup forKey:@"paulery"];
}

- (void)videoRecorderShineAnimationStop
{
    NSLog(@"%s", __func__);
    [self.videoRecorderShineImageView.layer removeAllAnimations];
    self.videoRecorderShineImageView.hidden = YES;
}

#pragma mark - Rotation
// ios 6 supports
- (UIInterfaceOrientationMask)supportedInterfaceOrientations
{
    NSLog(@"%s", __func__);
    return (1 << UIInterfaceOrientationPortrait);
}

- (BOOL)shouldAutorotate
{
    NSLog(@"%s", __func__);
    return NO;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    NSLog(@"%s", __func__);
    return NO;
}

- (void)dissmissVC
{
    NSLog(@"%s", __func__);
    [self dismissViewControllerAnimated:NO
                             completion:^(void){
                             }];
}

#pragma mark - Notification
- (void)applicationWillResignActive:(NSNotification *)notification
{
    if (self.mediaRecorder.isRecording) {
        [self onRecorderBtnTouchUp:nil];
    }
}

@end

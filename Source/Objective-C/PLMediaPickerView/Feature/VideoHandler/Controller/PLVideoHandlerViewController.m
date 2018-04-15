//
//  VideoHandlerViewController.m
//  QiuBai
//
//  Created by 小飞 刘 on 15/1/27.
//  Copyright (c) 2015年 Less Everything. All rights reserved.
//

#import "PLVideoHandlerViewController.h"
#import "PLVideoCropView.h"
#import "PLVideoRecorderHelper.h"
#import "PLSDAVAssetExportSession.h"
#import "PLUIHelper.h"
#import "UIImage+PLKIAdditions.h"
#import "UIDevice+PLScreenSizeCheck.h"
#import "UIButton+PLEnLargeEdge.h"
//#import <ReactiveCocoa.h>
#import "UIImage+PLExtends.h"
#import "PLFXBlurView.h"
#import "Constant.h"
#import <CommonCrypto/CommonDigest.h>

@interface PLVideoHandlerViewController ()

// view should hidden in iPhone4&4S
@property (weak, nonatomic) IBOutlet UILabel *labelNeedToHidden;
@property (weak, nonatomic) IBOutlet UIImageView *imgviewNeedToHidden;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *heightNeedToSet35;

@property (weak, nonatomic) AVPlayer *player; // video preview
@property (strong, nonatomic) AVPlayerItem *playerItem;
@property (strong, nonatomic) AVPlayerLayer *playerLayer;
@property (strong, nonatomic) NSURL *videoOutputFileURL;
@property (weak, nonatomic) id playerBoundaryTimeObserver;
@property (weak, nonatomic) id playerPeriodicTimeObserver;

// convert
@property (strong, nonatomic) AVAssetExportSession *exporter;
@property (strong, nonatomic) PLSDAVAssetExportSession *encoder;
@property (strong, nonatomic) NSURL *videoEncodedFileURL;
@property (strong, nonatomic) NSString *videoEncodedFilePath;

// ui
@property (strong, nonatomic) PLVideoCropView *cropView;
@property (weak, nonatomic) IBOutlet UIButton *videoPlayBtn;
@property (weak, nonatomic) IBOutlet UIView *preView;
@property (weak, nonatomic) IBOutlet UIImageView *videoWaterMaskImageView;
@property (retain, nonatomic) IBOutlet UIView *middleView;
@property (weak, nonatomic) IBOutlet UIView *videoEncodeMaskView;
@property (weak, nonatomic) IBOutlet UILabel *videoEncodeLoadingLabel;
@property (weak, nonatomic) IBOutlet UIImageView *videoEncodeLoadingImageView;
@property (weak, nonatomic) IBOutlet UIView *bottomView;
@property (strong, nonatomic) UIScrollView *videoPreScrollView;

// tips
@property (retain, nonatomic) IBOutlet UIImageView *pointToTopArrowImageView;
@property (retain, nonatomic) IBOutlet UIImageView *pointToBottomArrowImageView;
@property (nonatomic, strong) UIImageView *ratioTipImageView;

// gesture
@property (strong, nonatomic) UITapGestureRecognizer *preViewBtnTapGesture;

// others
@property (nonatomic, assign) BOOL initalized;
@property (nonatomic, assign) CGRect disRect;

@property (nonatomic, assign) BOOL isSquareRatio;
@property (nonatomic,strong) UIButton *navLeftBtn;

// outlet
- (IBAction)videoBtnPressed:(id)sender;

@end

@implementation PLVideoHandlerViewController

- (void)dealloc
{
    @try {
        [self removeObserver:self forKeyPath:@"player.rate"];
    } @catch (NSException *exception) {
    }
    
    if (self.playerBoundaryTimeObserver) {
        [self.player removeTimeObserver:self.playerBoundaryTimeObserver];
    }

    if (self.playerPeriodicTimeObserver) {
        [self.player removeTimeObserver:self.playerPeriodicTimeObserver];
    }
    [self.playerLayer removeFromSuperlayer];
    self.playerItem = nil;
    self.playerLayer = nil;
    [self.player pause];
    self.player = nil;
    self.navigationController.interactivePopGestureRecognizer.enabled = YES;
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    self.player = nil;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.view.frame = [[UIScreen mainScreen] bounds];
    [self.view setNeedsLayout];
    [self.view layoutIfNeeded];

    [self setNavigationBar];
    
    if (_initalized) {
        return;
    }

    // add player Oberver
    [self addObserver:self forKeyPath:@"player.rate" options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld context:nil];

    // cropView
    [self createCropView];

    // next btn
    UIButton *rightBarBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    rightBarBtn.titleLabel.font = [PLUIHelper fontWithSize:17.0f];
    [rightBarBtn setTitle:@"下一步" forState:UIControlStateNormal];
    [rightBarBtn setTitleColor:UIColorFromRGB(0xffa015) forState:UIControlStateNormal];
    [rightBarBtn sizeToFit];
    [rightBarBtn addTarget:self action:@selector(rightBarBtnPressed) forControlEvents:UIControlEventTouchUpInside];
    UIBarButtonItem *rightBarItem = [[UIBarButtonItem alloc] initWithCustomView:rightBarBtn];
    self.navigationItem.rightBarButtonItem = rightBarItem;

    // createViews
    [self createViews];

    self.view.backgroundColor = [UIColor colorWithRed:26 / 255.0 green:26 / 255.0 blue:31 / 255.0 alpha:1];

    self.navigationController.interactivePopGestureRecognizer.enabled = NO;

    // titleView
    UIButton *btn = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, 30, 30)];
    [btn setImage:[UIImage imageNamed:@"resource.bundle/videoCropSquare_off@3x.png"] forState:UIControlStateNormal];
    [btn addTarget:self action:@selector(titleViewBtnClick:) forControlEvents:UIControlEventTouchUpInside];
    [btn setEnlargeEdgeWithTop:10 right:10 bottom:10 left:10];
    self.navigationItem.titleView = btn;

    // titleView tip
    if ([PLVideoRecorderHelper onlyShowForTheFirstTimeForKey:@"videoCropSquareTip"]) {
        self.ratioTipImageView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"resource.bundle/videoCropSquareTip@3x.png"]];
        self.ratioTipImageView.frame = CGRectMake(0, 55, 100, 26);
        [[UIApplication sharedApplication].keyWindow addSubview:self.ratioTipImageView];
        [NSTimer scheduledTimerWithTimeInterval:3.0 target:self selector:@selector(hideRatioTipImageView) userInfo:nil repeats:NO];
    }

    self.isSquareRatio = NO;

    self.initalized = YES;
}

- (void)setNavigationBar
{
    self.navigationController.navigationBar.barTintColor = UIColorFromRGB(VideoSelectNavBackground);
    self.navigationController.navigationBar.tintColor = [UIColor whiteColor];
    [self.navigationController.navigationBar setTitleTextAttributes:@{NSForegroundColorAttributeName : UIColorFromRGB(VideoSelectNavTitle)}];
    
    UIButton *btn = [self setLeftBarItem:@"resource.bundle/icon_back@3x.png" accessibilityHint:@"点两下返回" accesssibilityLabel:@"返回"];
    [btn setEnlargeEdgeWithTop:10 right:25 bottom:10 left:15];
    [btn addTarget:self action:@selector(popVCwithAnimation) forControlEvents:UIControlEventTouchUpInside];
}

- (UIButton *)setLeftBarItem:(NSString *)imageName accessibilityHint:(NSString *)hint accesssibilityLabel:(NSString *)label
{
    UIImage *image = [UIImage imageNamed:imageName];
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    [button setImage:image forState:UIControlStateNormal];
    [button setShowsTouchWhenHighlighted:NO];
    [button setAdjustsImageWhenHighlighted:NO];
    button.frame= CGRectMake(0.0, 0.0, 48, image.size.height);
    button.imageEdgeInsets = UIEdgeInsetsMake(0, -42, 0, 0);
    UIBarButtonItem *forward = [[UIBarButtonItem alloc] initWithCustomView:button];
    forward.accessibilityHint = hint;
    forward.accessibilityLabel = label;
    self.navigationItem.leftBarButtonItem= forward;
    self.navLeftBtn = button;
    return button;
}

- (void)popVCwithAnimation
{
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)hideRatioTipImageView
{
    [UIView animateWithDuration:0.3
                     animations:^{
                         self.ratioTipImageView.alpha = 0.0;
                     }
                     completion:nil];
}

- (void)updateViewConstraints
{
    if (![UIDevice isWideScreenIPhone]) {
        self.imgviewNeedToHidden.hidden = YES;
        self.labelNeedToHidden.hidden = YES;
        [self.heightNeedToSet35 setConstant:35.0];
    }
    [super updateViewConstraints];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [self setApplicationStatusBarHidden:NO];
}

- (void)titleViewBtnClick:(id)sender
{
    UIButton *btn = (UIButton *) sender;
    if (self.isSquareRatio) {
        self.isSquareRatio = NO;
        [btn setImage:[UIImage imageNamed:@"resource.bundle/videoCropSquare_off@3x.png"] forState:UIControlStateNormal];
        [self preViewChangeToOriginRatio];
    } else {
        self.isSquareRatio = YES;
        [btn setImage:[UIImage imageNamed:@"resource.bundle/videoCropSquare_on@3x.png"] forState:UIControlStateNormal];
        [self preViewChangeToSquareRatio];
    }

    if (self.ratioTipImageView) {
        self.ratioTipImageView.hidden = YES;
    }
}

- (void)preViewChangeToOriginRatio
{
    AVAssetTrack *videoTrack = [[self.playerItem.asset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0];

    CGAffineTransform transform = videoTrack.preferredTransform;
    CGSize sizeOfVideo = videoTrack.naturalSize;
    CGRect rectOfVideo = CGRectZero;
    rectOfVideo.size = sizeOfVideo;
    CGSize resultSize = self.preView.bounds.size;
    rectOfVideo = CGRectApplyAffineTransform(rectOfVideo, transform);
    sizeOfVideo = rectOfVideo.size;

    if (sizeOfVideo.width > sizeOfVideo.height) {
        // 宽视频
        resultSize.width = self.preView.frame.size.width;
        resultSize.height = resultSize.width * sizeOfVideo.height / sizeOfVideo.width;
    } else if (sizeOfVideo.width < sizeOfVideo.height) {
        // 长视频
        resultSize.height = self.preView.frame.size.height;
        resultSize.width = resultSize.height * sizeOfVideo.width / sizeOfVideo.height;
    }

    self.videoPreScrollView.frame = CGRectMake(self.preView.frame.size.width / 2 - resultSize.width / 2, self.preView.frame.size.height / 2 - resultSize.height / 2, resultSize.width, resultSize.height);
    self.videoPreScrollView.contentSize = self.videoPreScrollView.frame.size;

    CGRect boundsOfPreviewLayer = CGRectZero;
    boundsOfPreviewLayer.size = resultSize;
    self.playerLayer.frame = boundsOfPreviewLayer;

    self.videoPreScrollView.showsVerticalScrollIndicator = NO;
    self.videoPreScrollView.showsHorizontalScrollIndicator = NO;
}

- (void)preViewChangeToSquareRatio
{
    self.videoPreScrollView.frame = self.preView.bounds;

    AVAssetTrack *videoTrack = [[self.playerItem.asset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0];

    CGAffineTransform transform = videoTrack.preferredTransform;
    CGSize sizeOfVideo = videoTrack.naturalSize;
    CGRect rectOfVideo = CGRectZero;
    rectOfVideo.size = sizeOfVideo;
    CGSize resultSize = self.preView.bounds.size;
    rectOfVideo = CGRectApplyAffineTransform(rectOfVideo, transform);
    sizeOfVideo = rectOfVideo.size;

    if (sizeOfVideo.width > sizeOfVideo.height) {
        // 宽视频
        resultSize.width = resultSize.height * sizeOfVideo.width / sizeOfVideo.height;
    } else if (sizeOfVideo.width < sizeOfVideo.height) {
        // 长视频
        resultSize.height = resultSize.width * sizeOfVideo.height / sizeOfVideo.width;
    }
    self.videoPreScrollView.contentSize = resultSize;
    CGRect boundsOfPreviewLayer = CGRectZero;
    boundsOfPreviewLayer.size = resultSize;
    self.playerLayer.frame = boundsOfPreviewLayer;

    // 上下左右居中
    if (resultSize.height > resultSize.width) {
        // 长视频
        self.videoPreScrollView.contentOffset = CGPointMake(0, (resultSize.height - self.videoPreScrollView.frame.size.height) / 2);
        self.videoPreScrollView.showsVerticalScrollIndicator = YES;
    } else if (resultSize.height < resultSize.width) {
        // 宽视频
        self.videoPreScrollView.contentOffset = CGPointMake((resultSize.width - self.videoPreScrollView.frame.size.width) / 2, 0);
        self.videoPreScrollView.showsHorizontalScrollIndicator = NO;
    }
}

- (void)setApplicationStatusBarHidden:(BOOL)hidden
{
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
    self.disRect = rect;

    [self dismissViewControllerAnimated:NO
                             completion:^(void) {
                                 // dismiss VideoRecorderVC
                                 [[NSNotificationCenter defaultCenter] postNotificationName:@"dismissVideoRecorderVCWhenCropVideoFinished" object:nil];
                             }];

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

#pragma mark - main method

- (void)createViews
{
    // videoPlayBtn
    [self.videoPlayBtn setImage:[UIImage imageNamed:@"resource.bundle/video_play@2x.png"] forState:UIControlStateNormal];
    self.videoPlayBtn.layer.zPosition = 4;

    // videoTips
    [self.pointToTopArrowImageView setImage:[UIImage imageNamed:@"resource.bundle/video_pointToTopArrow@3x.png"]];
    [self.pointToBottomArrowImageView setImage:[UIImage imageNamed:@"resource.bundle/video_pointToBottomArrow@3x.png"]];

    // waterMask
    self.videoWaterMaskImageView.layer.zPosition = 10;
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
    self.videoEncodeMaskView.backgroundColor = [UIColor blackColor];
    self.videoEncodeMaskView.hidden = YES;

    [self preViewRecorderedVideo];
}

- (void)createCropView
{
    NSLog(@"createCropView");
    self.cropView = [[PLVideoCropView alloc] initWithFrame:CGRectMake(0, 0, self.bottomView.frame.size.width, self.bottomView.frame.size.width / 5) withVideoAsset:self.videoAsset andVideoDuration:self.videoDuration];
    self.cropView.delegate = self;
    [self.bottomView addSubview:self.cropView];
}

- (void)preViewRecorderedVideo
{
    // player
    self.playerItem = [[AVPlayerItem alloc] initWithAsset:self.videoAsset];
    self.player = [AVPlayer playerWithPlayerItem:self.playerItem];
    self.player.actionAtItemEnd = AVPlayerActionAtItemEndNone;
    self.playerLayer = [AVPlayerLayer layer];
    [self.playerLayer setPlayer:self.player];
    [self.playerLayer setFrame:self.view.bounds];
    [self.playerLayer setVideoGravity:AVLayerVideoGravityResize];

    // videoPreScrollView
    self.videoPreScrollView = [[UIScrollView alloc] initWithFrame:self.preView.bounds];

    AVAssetTrack *videoTrack = [[self.playerItem.asset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0];

    CGAffineTransform transform = videoTrack.preferredTransform;
    CGSize sizeOfVideo = videoTrack.naturalSize;
    CGRect rectOfVideo = CGRectZero;
    rectOfVideo.size = sizeOfVideo;
    CGSize resultSize = self.preView.bounds.size;
    rectOfVideo = CGRectApplyAffineTransform(rectOfVideo, transform);
    sizeOfVideo = rectOfVideo.size;

    if (sizeOfVideo.width > sizeOfVideo.height) {
        // 宽视频
        resultSize.width = self.preView.frame.size.width;
        resultSize.height = resultSize.width * sizeOfVideo.height / sizeOfVideo.width;
    } else if (sizeOfVideo.width < sizeOfVideo.height) {
        // 长视频
        resultSize.height = self.preView.frame.size.height;
        resultSize.width = resultSize.height * sizeOfVideo.width / sizeOfVideo.height;
    }

    self.videoPreScrollView.frame = CGRectMake(self.preView.frame.size.width / 2 - resultSize.width / 2, self.preView.frame.size.height / 2 - resultSize.height / 2, resultSize.width, resultSize.height);
    self.videoPreScrollView.contentSize = self.videoPreScrollView.frame.size;

    CGRect boundsOfPreviewLayer = CGRectZero;
    boundsOfPreviewLayer.size = resultSize;
    self.playerLayer.frame = boundsOfPreviewLayer;

    self.videoPreScrollView.contentSize = resultSize;
    self.videoPreScrollView.bounces = NO;
    [self.videoPreScrollView.layer addSublayer:self.playerLayer];
    self.videoPreScrollView.indicatorStyle = UIScrollViewIndicatorStyleWhite;

    self.videoPreScrollView.showsVerticalScrollIndicator = NO;
    self.videoPreScrollView.showsHorizontalScrollIndicator = NO;

    // 上下左右居中
    if (resultSize.height > resultSize.width) {
        // 长视频
        self.videoPreScrollView.contentOffset = CGPointMake(0, (resultSize.height - self.videoPreScrollView.frame.size.height) / 2);
        self.videoPreScrollView.showsVerticalScrollIndicator = YES;
    } else if (resultSize.height < resultSize.width) {
        // 宽视频
        self.videoPreScrollView.contentOffset = CGPointMake((resultSize.width - self.videoPreScrollView.frame.size.width) / 2, 0);
        self.videoPreScrollView.showsHorizontalScrollIndicator = NO;
    }
    [self.preView addSubview:self.videoPreScrollView];
    [self.videoPreScrollView performSelector:@selector(flashScrollIndicators) withObject:nil afterDelay:1.0f];

    // gesture
    self.preViewBtnTapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(preViewPressed)];
    [self.preView addGestureRecognizer:self.preViewBtnTapGesture];

    if (self.playerPeriodicTimeObserver) {
    }
    __weak typeof(self) weakSelf = self;
    self.playerPeriodicTimeObserver = [self.player addPeriodicTimeObserverForInterval:CMTimeMake(0.01 * self.videoAsset.duration.timescale, self.videoAsset.duration.timescale)
                                                                                queue:NULL
                                                                           usingBlock:^(CMTime time) {
                                                                               [weakSelf updateVideoProgressBar];
                                                                           }];

    // observer
    [self addTimeObserver];

    // add Notification
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playItemDidReachEnd:) name:AVPlayerItemDidPlayToEndTimeNotification object:nil];
}

- (void)preViewPressed
{
    // 点击视频预览区域
    if (self.player.rate == 0) {
        NSLog(@"videoCropCurrentTime = %f  videoCropBeginTime = %f", self.cropView.videoCropCurrentTime, self.cropView.videoCropBeginTime);
        if (self.cropView.videoCropCurrentTime >= self.cropView.videoCropBeginTime) {
            NSLog(@"self.timescale = %d (self.cropView.videoCropCurrentTime)*self.avAsset.duration.timescale = %f", self.videoAsset.duration.timescale, (self.cropView.videoCropCurrentTime) * self.videoAsset.duration.timescale);

            __weak PLVideoHandlerViewController *weakSelf = self;
            [self.player seekToTime:CMTimeMake((self.cropView.videoCropBeginTime) * self.videoAsset.duration.timescale, self.videoAsset.duration.timescale)
                    toleranceBefore:kCMTimeZero
                     toleranceAfter:kCMTimeZero
                  completionHandler:^(BOOL finished) {
                      NSLog(@"player finished weakSelf.cropView.videoCropCurrentTime = weakSelf.cropView.videoCropBeginTime;");
                      weakSelf.cropView.videoCropCurrentTime = weakSelf.cropView.videoCropBeginTime;
                  }];
        }
        [self.player play];
    } else {
        [self.player pause];
    }
}

- (void)rightBarBtnPressed
{
    self.cropView.userInteractionEnabled = NO;
    [self.player pause];
    [self.player seekToTime:CMTimeMake((self.cropView.videoCropBeginTime) * self.videoAsset.duration.timescale, self.videoAsset.duration.timescale) toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero];
    self.videoPlayBtn.hidden = YES;
    self.videoEncodeMaskView.hidden = NO;
    self.videoEncodeLoadingImageView.hidden = NO;
    self.videoEncodeLoadingLabel.hidden = NO;

    // encode loading animation
    CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:@"transform.rotation.z"];
    animation.duration = ENCODELOADINGIMAGEVIEW_ANIMATION_DURATION;
    animation.fromValue = [NSNumber numberWithFloat:0.0];
    animation.toValue = [NSNumber numberWithFloat:2 * M_PI];
    animation.repeatCount = HUGE;
    [self.videoEncodeLoadingImageView.layer addAnimation:animation forKey:@"paulery"];

    // encode
    self.videoEncodedFilePath = [PLVideoRecorderHelper getFilePathByTime];
    self.videoEncodedFileURL = [NSURL fileURLWithPath:[[NSHomeDirectory() stringByAppendingPathComponent:@"Documents"] stringByAppendingPathComponent:self.videoEncodedFilePath]];
    [self convertVideoToLowQuailtyWithInputURL:self.videoAsset outputURL:self.videoEncodedFileURL];
}

- (NSUInteger)degressFromVideoTrack:(AVAssetTrack *)videoTrack
{
    NSUInteger degress = 0;

    CGAffineTransform t = videoTrack.preferredTransform;

    if (t.a == 0 && t.b == 1.0 && t.c == -1.0 && t.d == 0) {
        // Portrait
        degress = 90;
    } else if (t.a == 0 && t.b == -1.0 && t.c == 1.0 && t.d == 0) {
        // PortraitUpsideDown
        degress = 270;
    } else if (t.a == 1.0 && t.b == 0 && t.c == 0 && t.d == 1.0) {
        // LandscapeRight
        degress = 0;
    } else if (t.a == -1.0 && t.b == 0 && t.c == 0 && t.d == -1.0) {
        // LandscapeLeft
        degress = 180;
    }

    return degress;
}

- (CGAffineTransform)transformForVideoTrack:(AVAssetTrack *)videoTrack
{
    CGAffineTransform translateToCenter;
    CGAffineTransform mixedTransform;
    NSUInteger degrees = [self degressFromVideoTrack:videoTrack];

    switch (degrees) {
        case 90:
            //顺时针旋转90°
            NSLog(@"视频旋转90度,home按键在左");
            translateToCenter = CGAffineTransformMakeTranslation(videoTrack.naturalSize.height, 0.0);
            mixedTransform = CGAffineTransformRotate(translateToCenter, M_PI_2);
            break;
        case 180:
            //顺时针旋转180°
            NSLog(@"视频旋转180度，home按键在上");
            translateToCenter = CGAffineTransformMakeTranslation(videoTrack.naturalSize.width, videoTrack.naturalSize.height);
            mixedTransform = CGAffineTransformRotate(translateToCenter, M_PI);
            break;
        case 270:
            //顺时针旋转270°
            NSLog(@"视频旋转270度，home按键在右");
            translateToCenter = CGAffineTransformMakeTranslation(0.0, videoTrack.naturalSize.width);
            mixedTransform = CGAffineTransformRotate(translateToCenter, M_PI_2 * 3.0);
            break;

        default:
            mixedTransform = videoTrack.preferredTransform;
            break;
    }
    return mixedTransform;
}

#pragma mark - video convert

//转换image到cgimage

- (CVPixelBufferRef)pixelBufferFromCGImage:(CGImageRef)image

{
    NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:

                                              [NSNumber numberWithBool:YES], kCVPixelBufferCGImageCompatibilityKey,

                                              [NSNumber numberWithBool:YES],
                                              kCVPixelBufferCGBitmapContextCompatibilityKey,

                                              nil];

    CVPixelBufferRef pxbuffer = NULL;

    CVReturn status = CVPixelBufferCreate(kCFAllocatorDefault, self.view.frame.size.width,

                                          self.view.frame.size.height,
                                          kCVPixelFormatType_32ARGB,
                                          (__bridge CFDictionaryRef) options,

                                          &pxbuffer);

    NSParameterAssert(status == kCVReturnSuccess && pxbuffer != NULL);

    CVPixelBufferLockBaseAddress(pxbuffer, 0);

    void *pxdata = CVPixelBufferGetBaseAddress(pxbuffer);

    NSParameterAssert(pxdata != NULL);

    CGColorSpaceRef rgbColorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(pxdata, self.view.frame.size.width, self.view.frame.size.height, 8, 4 * self.view.frame.size.width, rgbColorSpace, kCGImageAlphaNoneSkipFirst);
    NSParameterAssert(context);
    CGContextConcatCTM(context, CGAffineTransformMakeRotation(0));
    CGContextDrawImage(context, CGRectMake(0, 0, CGImageGetWidth(image),

                                           CGImageGetHeight(image)),
                       image);
    CGColorSpaceRelease(rgbColorSpace);
    CGContextRelease(context);
    CVPixelBufferUnlockBaseAddress(pxbuffer, 0);
    return pxbuffer;
}

- (void)convertVideoToLowQuailtyWithInputURL:(AVAsset *)asset outputURL:(NSURL *)outputURL
{
    // video track
    NSError *error = nil;
    AVAssetTrack *clipVideoTrack = [[asset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0];

    //获取最后一帧的截图
    AVAssetImageGenerator *imageGenerator = [[AVAssetImageGenerator alloc] initWithAsset:asset];
    imageGenerator.appliesPreferredTrackTransform = YES;
    UIImage *lastImage;
    // calculate the midpoint time of video
    Float64 duration = CMTimeGetSeconds([asset duration]);
    CMTime midpoint = CMTimeMakeWithSeconds(duration, 600);
    CMTime actualTime;
    CGImageRef centerFrameImage = [imageGenerator copyCGImageAtTime:midpoint
                                                         actualTime:&actualTime
                                                              error:nil];
    if (centerFrameImage != NULL) {
        lastImage = [[[UIImage alloc] initWithCGImage:centerFrameImage] blurredImageWithRadius:20 iterations:3 tintColor:nil];
        CGImageRelease(centerFrameImage);
    }

    // insert timeRange
    CMTimeScale timescale = asset.duration.timescale;
    CMTimeRange range = CMTimeRangeMake(CMTimeMake(self.cropView.videoCropBeginTime * timescale, timescale), CMTimeMake((self.cropView.videoCropDurationTime + 2) * timescale, timescale));
    AVMutableComposition *composition = [AVMutableComposition composition];
    [composition insertTimeRange:range ofAsset:asset atTime:kCMTimeZero error:&error];

    // encoder
    self.encoder = [[PLSDAVAssetExportSession alloc] initWithAsset:composition];
    self.encoder.outputFileType = AVFileTypeMPEG4;
    self.encoder.outputURL = outputURL;
    NSString *level = AVVideoProfileLevelH264BaselineAutoLevel;

    // audio Setting
    self.encoder.audioSettings = @{ AVFormatIDKey : @(kAudioFormatMPEG4AAC), // ;
                                    AVNumberOfChannelsKey : @1,
                                    AVSampleRateKey : @44100,      // hz?
                                    AVEncoderBitRateKey : @128000, // bitrate?
    };

    // video Setting
    if (self.isSquareRatio) {
        // 正方形
        self.encoder.videoSettings = @{ AVVideoCodecKey : AVVideoCodecH264,
                                        AVVideoWidthKey : @(480), // frame
                                        AVVideoHeightKey : @(480),
                                        AVVideoScalingModeKey : AVVideoScalingModeResizeAspectFill, // resize
                                        AVVideoCompressionPropertiesKey : @{
                                            AVVideoAverageBitRateKey : @(2000000), // Bit rate
                                            AVVideoProfileLevelKey : level,
                                        },
        };

        // 创建视频截取区域
        AVMutableVideoComposition *videoComposition = [AVMutableVideoComposition videoComposition];
        videoComposition.frameDuration = CMTimeMake(1, 30);

        // 只需要取短的边作为视频截取的大小即可，因为我们是矩形
        CGFloat smallerSide = clipVideoTrack.naturalSize.width < clipVideoTrack.naturalSize.height ? clipVideoTrack.naturalSize.width : clipVideoTrack.naturalSize.height;
        videoComposition.renderSize = CGSizeMake(smallerSide, smallerSide);

        AVMutableVideoCompositionLayerInstruction *transformer = [AVMutableVideoCompositionLayerInstruction videoCompositionLayerInstructionWithAssetTrack:clipVideoTrack];

        // 计算缩放的因子，因为要放到scrollview里面肯定缩放了，但是只需要根据小的边计算就可以了
        // 因为缩放的时候是把小的边缩放到和scrollview的宽度或是高度那么大，然后等比缩放另一条边
        CGFloat scaleFactor = smallerSide / self.videoPreScrollView.frame.size.width;
        // 根据缩放因子计算x，y的偏移量
        CGFloat xOffset = self.videoPreScrollView.contentOffset.x * scaleFactor;
        CGFloat yOffset = self.videoPreScrollView.contentOffset.y * scaleFactor;

        CGAffineTransform finalTransform = clipVideoTrack.preferredTransform;
        finalTransform = [self transformForVideoTrack:clipVideoTrack];

        // 如果视频的宽高相同，那么就不用做移动了，因为我们的就是矩形的视频
        if (clipVideoTrack.naturalSize.width == clipVideoTrack.naturalSize.height) {
            xOffset = 0;
            yOffset = 0;
        }
        // 根据视频的仿射变换的矩阵计算x，y的实际偏移量
        CGFloat xTranslate = finalTransform.a * xOffset + finalTransform.c * yOffset;
        CGFloat yTranslate = finalTransform.b * xOffset + finalTransform.d * yOffset;
        // 横屏的话，x方向的偏移量是反的
        if (self.videoPreScrollView.contentSize.width > self.videoPreScrollView.contentSize.height) {
            xTranslate = -xTranslate;
        } else {
            yTranslate = -yTranslate;
        }
        finalTransform = CGAffineTransformTranslate(finalTransform, xTranslate, yTranslate);
        [transformer setTransform:finalTransform atTime:kCMTimeZero];

        // create instruction
        AVMutableVideoCompositionInstruction *instruction = [AVMutableVideoCompositionInstruction videoCompositionInstruction];
        instruction.timeRange = CMTimeRangeMake(kCMTimeZero, range.duration);
        videoComposition.instructions = [NSArray arrayWithObject:instruction];
        instruction.layerInstructions = [NSArray arrayWithObject:transformer];

        //add video tail
        [PLVideoRecorderHelper addVideoTail:videoComposition lastImage:lastImage totalDuration:composition.duration];

        [self.encoder setVideoComposition:videoComposition];

    } else {
        // 原比例
        AVAssetTrack *videoTrack = [[self.playerItem.asset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0];
        CGSize sizeOfVideo = videoTrack.naturalSize;
        CGFloat maxL = 800; // 最长边800
        CGFloat destHeight = sizeOfVideo.height;
        CGFloat destWidth = sizeOfVideo.width;

        if (sizeOfVideo.height >= sizeOfVideo.width) {
            // 长视频
            if (destHeight > maxL) {
                destHeight = maxL;
                destWidth = destHeight * sizeOfVideo.width / sizeOfVideo.height;
            }
        } else {
            // 宽视频
            if (destWidth > maxL) {
                destWidth = maxL;
                destHeight = destWidth * sizeOfVideo.height / sizeOfVideo.width;
            }
        }

        NSUInteger degrees = [self degressFromVideoTrack:videoTrack];
        if (degrees == 90 || degrees == 270) {
            CGFloat tmp = destWidth;
            destWidth = destHeight;
            destHeight = tmp;
        }

        self.encoder.videoSettings = @{ AVVideoCodecKey : AVVideoCodecH264,
                                        AVVideoWidthKey : @(destWidth), // frame
                                        AVVideoHeightKey : @(destHeight),
                                        AVVideoScalingModeKey : AVVideoScalingModeResizeAspectFill, // resize
                                        AVVideoCompressionPropertiesKey : @{
                                            AVVideoAverageBitRateKey : @(500 * 1024), // Bit rate
                                            AVVideoProfileLevelKey : level,
                                        },
        };
        // 创建视频截取区域
        AVMutableVideoComposition *videoComposition = [AVMutableVideoComposition videoComposition];
        videoComposition.frameDuration = CMTimeMake(1, 30);

        // 只需要取短的边作为视频截取的大小即可，因为我们是矩形
        CGFloat biggerSide = clipVideoTrack.naturalSize.width > clipVideoTrack.naturalSize.height ? clipVideoTrack.naturalSize.width : clipVideoTrack.naturalSize.height;
        //        CGFloat smallerSide = clipVideoTrack.naturalSize.width < clipVideoTrack.naturalSize.height ? clipVideoTrack.naturalSize.width : clipVideoTrack.naturalSize.height;
        videoComposition.renderSize = clipVideoTrack.naturalSize;
        if (degrees == 90 || degrees == 270) {
            videoComposition.renderSize = CGSizeMake(clipVideoTrack.naturalSize.height, clipVideoTrack.naturalSize.width);
        }

        AVMutableVideoCompositionLayerInstruction *transformer = [AVMutableVideoCompositionLayerInstruction videoCompositionLayerInstructionWithAssetTrack:clipVideoTrack];

        // 计算缩放的因子，因为要放到scrollview里面肯定缩放了，但是只需要根据小的边计算就可以了
        // 因为缩放的时候是把小的边缩放到和scrollview的宽度或是高度那么大，然后等比缩放另一条边
        CGFloat scaleFactor = biggerSide / self.videoPreScrollView.frame.size.width;
        // 根据缩放因子计算x，y的偏移量
        CGFloat xOffset = self.videoPreScrollView.contentOffset.x * scaleFactor;
        CGFloat yOffset = self.videoPreScrollView.contentOffset.y * scaleFactor;

        CGAffineTransform finalTransform = clipVideoTrack.preferredTransform;
        finalTransform = [self transformForVideoTrack:clipVideoTrack];

        // 如果视频的宽高相同，那么就不用做移动了，因为我们的就是矩形的视频
        if (clipVideoTrack.naturalSize.width == clipVideoTrack.naturalSize.height) {
            xOffset = 0;
            yOffset = 0;
        }
        // 根据视频的仿射变换的矩阵计算x，y的实际偏移量
        CGFloat xTranslate = finalTransform.a * xOffset + finalTransform.c * yOffset;
        CGFloat yTranslate = finalTransform.b * xOffset + finalTransform.d * yOffset;
        // 横屏的话，x方向的偏移量是反的
        if (self.videoPreScrollView.contentSize.width > self.videoPreScrollView.contentSize.height) {
            xTranslate = -xTranslate;
        } else {
            yTranslate = -yTranslate;
        }
        finalTransform = CGAffineTransformTranslate(finalTransform, xTranslate, yTranslate);
        [transformer setTransform:finalTransform atTime:kCMTimeZero];

        // create instruction
        AVMutableVideoCompositionInstruction *instruction = [AVMutableVideoCompositionInstruction videoCompositionInstruction];
        instruction.timeRange = CMTimeRangeMake(kCMTimeZero, range.duration);
        videoComposition.instructions = [NSArray arrayWithObject:instruction];
        instruction.layerInstructions = [NSArray arrayWithObject:transformer];

        //add video tail
        [PLVideoRecorderHelper addVideoTail:videoComposition lastImage:lastImage totalDuration:composition.duration];

        [self.encoder setVideoComposition:videoComposition];
    }

    // call back
    __weak typeof(self) weakSelf = self;
    [self.encoder exportAsynchronouslyWithCompletionHandler:^{
        if (weakSelf.encoder.status == AVAssetExportSessionStatusCompleted) {
            NSLog(@"AVAssetExportSessionStatusCompleted");
            NSData *videoData = [NSData dataWithContentsOfURL:outputURL];
            NSString *videoOriginHash = [self MD5HexDigest:videoData];
            
            UIImage *videoPreViewImage = [UIImage thumbnailImageForVideo:outputURL atTime:0.1];
            dispatch_async(dispatch_get_main_queue(), ^{
                if ([weakSelf.delegate respondsToSelector:@selector(onVideoSelectedWithPath:firstImg:videoOriginHash:)]) {
                    [weakSelf.delegate onVideoSelectedWithPath:self.videoEncodedFilePath firstImg:videoPreViewImage videoOriginHash:videoOriginHash];
                }
                CGRect rect = CGRectZero;
                if ([weakSelf.delegate respondsToSelector:@selector(animateEndRect)]) {
                    rect = [weakSelf.delegate animateEndRect];
                }
                [weakSelf dismissViewControllerAnimated:YES completion:nil];
            });

        } else if (weakSelf.encoder.status == AVAssetExportSessionStatusFailed) {
            NSLog(@"AVAssetExportSessionStatusFailed");
        } else if (weakSelf.encoder.status == AVAssetExportSessionStatusExporting) {
            NSLog(@"AVAssetExportSessionStatusExporting....");

        } else if (weakSelf.encoder.status == AVAssetExportSessionStatusCancelled) {
            NSLog(@"AVAssetExportSessionStatusCancelled");
        }
    }];
}

- (NSString *)MD5HexDigest:(NSData *)input
{
    unsigned char result[CC_MD5_DIGEST_LENGTH];
    CC_MD5(input.bytes, (int)input.length,result);
    NSMutableString *ret = [NSMutableString stringWithCapacity:CC_MD5_DIGEST_LENGTH*2];
    for (int i = 0; i<CC_MD5_DIGEST_LENGTH; i++) {
        [ret appendFormat:@"%02x",result[i]];
    }
    return ret;
}

#pragma mark - outlet

- (IBAction)videoBtnPressed:(id)sender
{
    [self.player play];
}

#pragma mark - Rotation
// ios 6 supports
- (UIInterfaceOrientationMask)supportedInterfaceOrientations
{
    return (1 << UIInterfaceOrientationPortrait);
}

- (BOOL)shouldAutorotate
{
    return NO;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return NO;
}

#pragma mark - Notification

- (void)playItemDidReachEnd:(NSNotification *)notification
{
    [self.player pause];
    [self.player seekToTime:CMTimeMake((self.cropView.videoCropBeginTime) * self.videoAsset.duration.timescale, self.videoAsset.duration.timescale) toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero];
    self.videoPlayBtn.hidden = NO;
}

#pragma mark - KVO

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (((PLVideoHandlerViewController *) object).player != self.player) {
        return;
    }
    if (change[@"old"] == [NSNull null] || change[@"new"] == [NSNull null]) {
        return;
    }
    if ([change[@"old"] integerValue] == 0 && [change[@"new"] integerValue] == 0) {
        return;
    }
    if (self.player.rate == 0) {
        self.videoPlayBtn.hidden = NO;
    } else {
        self.videoPlayBtn.hidden = YES;
    }
}

#pragma mark - VideoCropView delegate

- (void)updateVideoPreImage
{
    [self.player pause];

    [self.player seekToTime:CMTimeMake((self.cropView.videoCropPreCurTime) * self.videoAsset.duration.timescale, self.videoAsset.duration.timescale) toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero];

    NSLog(@"start:%f,end:%f,current:%f,duration:%f", self.cropView.videoCropBeginTime, self.cropView.videoCropEndTime, self.cropView.videoCropPreCurTime, self.cropView.videoCropDurationTime);

    [self addTimeObserver];
}

#pragma mark - TimeObserver

- (void)addTimeObserver
{
    if (self.playerBoundaryTimeObserver) {
        [self.player removeTimeObserver:self.playerBoundaryTimeObserver];
    }

    if (self.playerPeriodicTimeObserver) {
        [self.player removeTimeObserver:self.playerPeriodicTimeObserver];
    }

    __weak typeof(self) weakSelf = self;
    self.playerBoundaryTimeObserver = [self.player addBoundaryTimeObserverForTimes:[NSArray arrayWithObject:[NSValue valueWithCMTime:CMTimeMake(self.cropView.videoCropEndTime * self.videoAsset.duration.timescale, self.videoAsset.duration.timescale)]]
                                                                             queue:NULL
                                                                        usingBlock:^(void) {
                                                                            [weakSelf.player seekToTime:CMTimeMake((weakSelf.cropView.videoCropBeginTime) * weakSelf.videoAsset.duration.timescale, weakSelf.videoAsset.duration.timescale) toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero];
                                                                            [weakSelf.player pause];
                                                                        }];

    self.playerPeriodicTimeObserver = [self.player addPeriodicTimeObserverForInterval:CMTimeMake(0.01 * self.videoAsset.duration.timescale, self.videoAsset.duration.timescale)
                                                                                queue:NULL
                                                                           usingBlock:^(CMTime time) {
                                                                               [weakSelf updateVideoProgressBar];
                                                                           }];
}

- (void)updateVideoProgressBar
{
    CGFloat currentTime = CMTimeGetSeconds([self.player currentTime]);
    CGFloat currentProgress = (currentTime - self.cropView.videoCropBeginTime) / self.cropView.videoCropDurationTime;
    [self.cropView setProgressBar:currentProgress];
}

@end

//
//  VideoCropView.m
//  QiuBai
//
//  Created by 小飞 刘 on 15/1/27.
//  Copyright (c) 2015年 Less Everything. All rights reserved.
//

#import "PLVideoCropView.h"
#import "PLVideoCropHanderView.h"
#import "Constant.h"

@interface PLVideoCropView ()

@property (strong, nonatomic) UIScrollView *scrollView;

@property (strong, nonatomic) PLVideoCropHanderView *videoCropHandlerView;
@property (strong, nonatomic) UIImageView *videoCropLeftHandlerImageView;
@property (strong, nonatomic) UIView *videoCropLeftHandlerMaskView;
@property (strong, nonatomic) UIImageView *videoCropRightHandlerImageView;
@property (strong, nonatomic) UIView *videoCropRightHandlerMaskView;

@property (nonatomic) UIPanGestureRecognizer *leftPanGesture;
@property (nonatomic) UIPanGestureRecognizer *rightPanGesture;
@property (nonatomic) UIPanGestureRecognizer *leftMaskViewPanGesture;
@property (nonatomic) UIPanGestureRecognizer *rightMaskViewPanGesture;

@property (nonatomic) CGFloat videoCropLeftProcess;
@property (nonatomic) CGFloat videoCropRightProcess;
@property (nonatomic) CGFloat timeOfScreenWidth;
@property (nonatomic) CGFloat videoMinPercent;
@property (nonatomic) CGFloat videoGap;

@property (nonatomic) CGFloat totalViewCount;
@property (nonatomic) NSInteger numberOfViewsInScrollView;
@property (nonatomic) CGFloat thumbNailWidth;
@property (nonatomic) CGFloat thumbNailHeight;

@end

@implementation PLVideoCropView

- (instancetype)initWithFrame:(CGRect)frame withVideoAsset:(AVAsset *)videoAsset andVideoDuration:(CGFloat)videoDuration;
{
    self = [super initWithFrame:frame];

    if (self) {
        self.backgroundColor = [UIColor clearColor];
        self.videoDuration = videoDuration;
        self.videoAsset = videoAsset;

        // thumb
        self.numberOfViewsInScrollView = VIDEO_THUMB_NUMBER;
        self.thumbNailWidth = self.frame.size.width / self.numberOfViewsInScrollView;
        self.thumbNailHeight = self.frame.size.width / self.numberOfViewsInScrollView * 2;

        // time & precess
        self.videoGap = 0;
        if (self.videoDuration >= VIDEO_MAX_DURATION) {
            self.timeOfScreenWidth = VIDEO_MAX_DURATION; // self.frame.size.width represent 180 seconds

            self.videoCropEndTime = VIDEO_MAX_DURATION;
            self.videoMinPercent = (CGFloat) VIDEO_MIN_DURATION / VIDEO_MAX_DURATION;
            self.videoGap = VIDEO_MAX_DURATION / self.numberOfViewsInScrollView;
        } else {
            self.timeOfScreenWidth = self.videoDuration; // self.frame.size.width represent video duration

            self.videoCropEndTime = self.videoDuration;

            self.videoMinPercent = (VIDEO_MIN_DURATION / self.videoDuration > 1) ? 1 : VIDEO_MIN_DURATION / self.videoDuration;
            self.videoGap = self.videoDuration / self.numberOfViewsInScrollView;
        }
        self.totalViewCount = self.videoDuration / self.videoGap;

        // crop view
        self.videoCropLeftProcess = 0.0f;
        self.videoCropRightProcess = 1.0;
        self.videoCropBeginTime = 0.0f;
        self.videoCropDurationTime = self.videoCropEndTime - self.videoCropBeginTime;
        self.videoCropCurrentTime = self.videoCropBeginTime;
        self.videoCropPreCurTime = self.videoCropBeginTime;

        // scrollView
        [self creatScrollView];

        // thunbNail
        [self creatThumbNail];

        // hanler
        [self creatHanler];

        // progressBar
        [self creatProgressBar];

        // cornerRadius
        if (self.videoDuration < VIDEO_MAX_DURATION) {
            self.scrollView.layer.cornerRadius = 5;
        }
    }

    return self;
}

- (void)drawRect:(CGRect)rect
{
    [super drawRect:rect];
}

- (void)creatScrollView
{
    self.scrollView = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 0, self.frame.size.width, self.thumbNailHeight)];
    self.scrollView.delegate = self;
    self.scrollView.bounces = NO;
    self.scrollView.contentSize = CGSizeMake(self.thumbNailWidth * self.totalViewCount, self.thumbNailHeight);
    self.scrollView.showsHorizontalScrollIndicator = NO;
    self.scrollView.showsVerticalScrollIndicator = NO;
    [self addSubview:self.scrollView];
}

- (void)creatThumbNail
{
    AVAssetImageGenerator *generator = [[AVAssetImageGenerator alloc] initWithAsset:self.videoAsset];
    generator.appliesPreferredTrackTransform = YES;
    generator = [[AVAssetImageGenerator alloc] initWithAsset:self.videoAsset];
    generator.appliesPreferredTrackTransform = YES;
    generator.maximumSize = CGSizeMake(60, 120);

    NSArray *times = [self generateThumbnailTimesForVideo:self.videoAsset];

    __block NSInteger index = 0;
    __weak typeof(self) weakSelf = self;
    [generator generateCGImagesAsynchronouslyForTimes:times
                                    completionHandler:^(CMTime requestedTime,
                                                        CGImageRef image,
                                                        CMTime actualTime,
                                                        AVAssetImageGeneratorResult result,
                                                        NSError *error) {
                                        if (result == AVAssetImageGeneratorSucceeded) {
                                            dispatch_sync(dispatch_get_main_queue(), ^{
                                                UIImageView *imageView = [[UIImageView alloc] initWithFrame:CGRectMake(weakSelf.thumbNailWidth * index, 0, weakSelf.thumbNailWidth, weakSelf.thumbNailHeight)];
                                                imageView.image = [UIImage imageWithCGImage:image];
                                                imageView.contentMode = UIViewContentModeScaleAspectFill;
                                                [weakSelf.scrollView addSubview:imageView];
                                                index++;
                                            });
                                        }
                                    }];
}

- (void)creatHanler
{
    // crop handler view
    self.videoCropHandlerView = [[PLVideoCropHanderView alloc] initWithFrame:self.scrollView.frame];
    self.videoCropHandlerView.layer.cornerRadius = 5;
    self.videoCropHandlerView.layer.borderWidth = 1;
    self.videoCropHandlerView.layer.borderColor = UIColorFromRGB(0xffa015).CGColor;
    [self addSubview:self.videoCropHandlerView];

    // crop handler view frame kvo
    [self addObserver:self forKeyPath:@"videoCropHandlerView.frame" options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld context:nil];

    // width of handler
    CGFloat handlerScaleFactor = self.videoCropHandlerView.frame.size.height / 60.0f;
    CGFloat widthOfHandler = handlerScaleFactor * 20.0f;

    // leftHandler
    self.videoCropLeftHandlerImageView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, widthOfHandler, self.videoCropHandlerView.frame.size.height)];
    self.videoCropLeftHandlerImageView.userInteractionEnabled = YES;
    [self.videoCropLeftHandlerImageView becomeFirstResponder];
    self.videoCropLeftHandlerImageView.clipsToBounds = YES;
    self.videoCropLeftHandlerImageView.image = [UIImage imageNamed:@"resource.bundle/video_crop_handle_left@3x.png"];
    [self.videoCropHandlerView addSubview:self.videoCropLeftHandlerImageView];

    self.videoCropLeftHandlerMaskView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 0, self.videoCropHandlerView.frame.size.height)];
    self.videoCropLeftHandlerMaskView.userInteractionEnabled = YES;
    self.videoCropLeftHandlerMaskView.backgroundColor = [UIColor blackColor];
    self.videoCropLeftHandlerMaskView.alpha = 0.7;
    [self addSubview:self.videoCropLeftHandlerMaskView];

    // rightHandler
    self.videoCropRightHandlerImageView = [[UIImageView alloc] initWithFrame:CGRectMake(self.videoCropHandlerView.frame.size.width - widthOfHandler, 0, widthOfHandler, self.videoCropHandlerView.frame.size.height)];
    self.videoCropRightHandlerImageView.userInteractionEnabled = YES;
    [self.videoCropRightHandlerImageView becomeFirstResponder];
    self.videoCropRightHandlerImageView.image = [UIImage imageNamed:@"resource.bundle/video_crop_handle_right@3x.png"];
    [self.videoCropHandlerView addSubview:self.videoCropRightHandlerImageView];

    self.videoCropRightHandlerMaskView = [[UIView alloc] initWithFrame:CGRectMake(self.videoCropHandlerView.frame.size.width, 0, 0, self.videoCropHandlerView.frame.size.height)];
    self.videoCropRightHandlerMaskView.userInteractionEnabled = YES;
    self.videoCropRightHandlerMaskView.backgroundColor = [UIColor blackColor];
    self.videoCropRightHandlerMaskView.alpha = 0.7;
    self.videoCropRightHandlerMaskView.clipsToBounds = YES;
    [self addSubview:self.videoCropRightHandlerMaskView];

    // pan gesture
    self.leftPanGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(leftPan:)];
    [self.videoCropRightHandlerImageView addGestureRecognizer:self.leftPanGesture];

    self.leftMaskViewPanGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(leftMaskViewPan:)];
    [self.videoCropRightHandlerMaskView addGestureRecognizer:self.leftMaskViewPanGesture];

    self.rightPanGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(rightPan:)];
    [self.videoCropLeftHandlerImageView addGestureRecognizer:self.rightPanGesture];

    self.rightMaskViewPanGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(rightMaskViewPan:)];
    [self.videoCropLeftHandlerMaskView addGestureRecognizer:self.rightMaskViewPanGesture];
}

- (void)creatProgressBar
{
    self.videoPlayProgressBar = [[UIView alloc] initWithFrame:CGRectMake(0, 1, 2, self.videoCropHandlerView.frame.size.height - 2)];
    self.videoPlayProgressBar.backgroundColor = [UIColor whiteColor];
    self.videoPlayProgressBar.hidden = YES;
    [self.videoCropHandlerView insertSubview:self.videoPlayProgressBar atIndex:0];
}

- (void)setProgressBar:(CGFloat)progress
{
    CGFloat minProgress = self.videoCropLeftHandlerImageView.frame.size.width * 0.5 / self.videoCropHandlerView.frame.size.width;
    CGFloat maxProgress = (self.videoCropHandlerView.frame.size.width - self.videoCropRightHandlerImageView.frame.size.width * 0.5 - self.videoPlayProgressBar.frame.size.width) / self.videoCropHandlerView.frame.size.width;

    if (progress >= minProgress && progress <= maxProgress) {
        self.videoPlayProgressBar.hidden = NO;
        self.videoPlayProgressBar.frame = CGRectMake(self.videoCropHandlerView.frame.size.width * progress, 0, 2, self.videoCropHandlerView.frame.size.height);
        self.videoCropCurrentTime = (self.videoCropDurationTime - self.videoCropBeginTime) * ((progress - minProgress) / (maxProgress - minProgress));
    } else {
        self.videoPlayProgressBar.hidden = YES;
    }
}

#pragma mark - CMTimes

- (NSArray *)generateThumbnailTimesForVideo:(AVAsset *)asset
{
    CGFloat duration = CMTimeGetSeconds(asset.duration);
    NSMutableArray *array = [[NSMutableArray alloc] init];

    for (int index = 0; index < duration / self.videoGap; index++) {
        CMTime time = CMTimeMake((index * self.videoGap) * asset.duration.timescale, asset.duration.timescale);
        NSValue *value = [NSValue valueWithCMTime:time];
        [array addObject:value];
    }
    self.totalViewCount = array.count;
    return array;
}

#pragma mark - panGesture

- (void)leftPan:(UIPanGestureRecognizer *)sender
{
    CGPoint translation = [sender translationInView:self.videoCropRightHandlerImageView];
    CGFloat rightTobe = (self.videoCropHandlerView.frame.origin.x + self.videoCropHandlerView.frame.size.width + translation.x) / self.frame.size.width;
    CGFloat translationX = translation.x;

    if (self.videoDuration >= VIDEO_MAX_DURATION) {
        if (rightTobe - self.videoCropLeftProcess <= self.videoMinPercent) {
            self.videoCropRightProcess = self.videoCropLeftProcess + self.videoMinPercent;
            translationX = -(self.videoCropRightHandlerImageView.frame.origin.x - self.videoMinPercent * self.frame.size.width + self.videoCropRightHandlerImageView.frame.size.width);
        } else if (rightTobe > 1.0) {
            self.videoCropRightProcess = 1.0;
            translationX = self.frame.size.width - (self.videoCropHandlerView.frame.origin.x + self.videoCropHandlerView.frame.size.width);
        } else {
            self.videoCropRightProcess = rightTobe;
        }
    } else {
        if (rightTobe > 1) {
            self.videoCropRightProcess = 1;
            translationX = self.frame.size.width - self.videoCropRightHandlerImageView.frame.size.width - self.videoCropRightHandlerImageView.frame.origin.x - self.videoCropHandlerView.frame.origin.x;
        } else if (rightTobe - self.videoCropLeftProcess <= self.videoMinPercent) {
            self.videoCropRightProcess = self.videoCropLeftProcess + self.videoMinPercent;
            translationX = -(self.videoCropRightHandlerImageView.frame.origin.x - self.videoMinPercent * self.frame.size.width + self.videoCropRightHandlerImageView.frame.size.width);
        } else {
            self.videoCropRightProcess = rightTobe;
        }
    }

    sender.view.center = CGPointMake(sender.view.center.x + translationX, sender.view.center.y);
    [sender setTranslation:CGPointZero inView:self.videoCropRightHandlerImageView];

    // time
    self.videoCropEndTime = (self.scrollView.contentOffset.x / self.frame.size.width + self.videoCropRightProcess) * self.timeOfScreenWidth;
    self.videoCropDurationTime = self.videoCropEndTime - self.videoCropBeginTime;
    self.videoCropCurrentTime = self.videoCropBeginTime;
    self.videoCropPreCurTime = self.videoCropEndTime;

    // update CropHandlerView
    self.videoCropHandlerView.frame = CGRectMake(self.videoCropHandlerView.frame.origin.x, self.videoCropHandlerView.frame.origin.y, self.videoCropHandlerView.frame.size.width + translationX, self.videoCropHandlerView.frame.size.height);

    // MaskView frame
    self.videoCropRightHandlerMaskView.frame = CGRectMake(self.videoCropHandlerView.frame.origin.x + self.videoCropHandlerView.frame.size.width, 0, self.scrollView.frame.size.width - (self.videoCropHandlerView.frame.origin.x + self.videoCropHandlerView.frame.size.width), self.videoCropRightHandlerMaskView.frame.size.height);
}

- (void)rightPan:(UIPanGestureRecognizer *)sender
{
    CGPoint translation = [sender translationInView:self.videoCropLeftHandlerImageView];
    CGFloat leftTobe = (self.videoCropHandlerView.frame.origin.x + translation.x) / self.frame.size.width;
    CGFloat translationX = translation.x;
    if (self.videoCropRightProcess - leftTobe <= self.videoMinPercent) {
        self.videoCropLeftProcess = self.videoCropRightProcess - self.videoMinPercent;
        translationX = self.videoCropRightHandlerImageView.frame.origin.x + self.videoCropRightHandlerImageView.frame.size.width - self.videoMinPercent * self.frame.size.width - self.videoCropLeftHandlerImageView.frame.origin.x;
    } else if (leftTobe < 0.0) {
        self.videoCropLeftProcess = 0.0;
        translationX = -self.videoCropHandlerView.frame.origin.x;
    } else {
        self.videoCropLeftProcess = leftTobe;
    }
    sender.view.center = CGPointMake(sender.view.center.x + translation.x, sender.view.center.y);
    [sender setTranslation:CGPointZero inView:self.videoCropLeftHandlerImageView];

    // time
    self.videoCropBeginTime = (self.scrollView.contentOffset.x / self.frame.size.width + self.videoCropLeftProcess) * self.timeOfScreenWidth;
    self.videoCropDurationTime = self.videoCropEndTime - self.videoCropBeginTime;
    self.videoCropPreCurTime = self.videoCropBeginTime;
    self.videoCropCurrentTime = self.videoCropBeginTime;

    // update CropHandlerView
    self.videoCropHandlerView.frame = CGRectMake(self.videoCropHandlerView.frame.origin.x + translationX, self.videoCropHandlerView.frame.origin.y, self.videoCropHandlerView.frame.size.width - translationX, self.videoCropHandlerView.frame.size.height);

    // MaskView frame
    self.videoCropLeftHandlerMaskView.frame = CGRectMake(0, 0, self.videoCropHandlerView.frame.origin.x, self.videoCropLeftHandlerMaskView.frame.size.height);
}

- (void)leftMaskViewPan:(UIPanGestureRecognizer *)sender
{
    CGPoint translation = [sender translationInView:self.videoCropRightHandlerMaskView];
    CGFloat rightTobe = (self.videoCropHandlerView.frame.origin.x + self.videoCropHandlerView.frame.size.width + translation.x) / self.frame.size.width;
    CGFloat translationX = translation.x;

    if (self.videoDuration >= VIDEO_MAX_DURATION) {
        if (rightTobe - self.videoCropLeftProcess <= self.videoMinPercent) {
            self.videoCropRightProcess = self.videoCropLeftProcess + self.videoMinPercent;
            translationX = -(self.videoCropRightHandlerImageView.frame.origin.x - self.videoMinPercent * self.frame.size.width + self.videoCropRightHandlerImageView.frame.size.width);
        } else if (rightTobe > 1.0) {
            self.videoCropRightProcess = 1.0;
            translationX = self.frame.size.width - (self.videoCropHandlerView.frame.origin.x + self.videoCropHandlerView.frame.size.width);
        } else {
            self.videoCropRightProcess = rightTobe;
        }
    } else {
        if (rightTobe > 1) {
            self.videoCropRightProcess = 1;
            translationX = self.frame.size.width - self.videoCropRightHandlerImageView.frame.size.width - self.videoCropRightHandlerImageView.frame.origin.x - self.videoCropHandlerView.frame.origin.x;
        } else if (rightTobe - self.videoCropLeftProcess <= self.videoMinPercent) {
            self.videoCropRightProcess = self.videoCropLeftProcess + self.videoMinPercent;
            translationX = -(self.videoCropRightHandlerImageView.frame.origin.x - self.videoMinPercent * self.frame.size.width + self.videoCropRightHandlerImageView.frame.size.width);
        } else {
            self.videoCropRightProcess = rightTobe;
        }
    }

    sender.view.center = CGPointMake(sender.view.center.x + translationX, sender.view.center.y);
    [sender setTranslation:CGPointZero inView:self.videoCropRightHandlerMaskView];

    // time
    self.videoCropEndTime = (self.scrollView.contentOffset.x / self.frame.size.width + self.videoCropRightProcess) * self.timeOfScreenWidth;
    self.videoCropDurationTime = self.videoCropEndTime - self.videoCropBeginTime;
    self.videoCropPreCurTime = self.videoCropEndTime;
    self.videoCropCurrentTime = self.videoCropBeginTime;

    // update CropHandlerView
    self.videoCropHandlerView.frame = CGRectMake(self.videoCropHandlerView.frame.origin.x, self.videoCropHandlerView.frame.origin.y, self.videoCropHandlerView.frame.size.width + translationX, self.videoCropHandlerView.frame.size.height);

    // MaskView frame
    self.videoCropRightHandlerMaskView.frame = CGRectMake(self.videoCropHandlerView.frame.origin.x + self.videoCropHandlerView.frame.size.width, 0, self.scrollView.frame.size.width - (self.videoCropHandlerView.frame.origin.x + self.videoCropHandlerView.frame.size.width), self.videoCropRightHandlerMaskView.frame.size.height);
}

- (void)rightMaskViewPan:(UIPanGestureRecognizer *)sender
{
    CGPoint translation = [sender translationInView:self.videoCropLeftHandlerMaskView];
    CGFloat leftTobe = (self.videoCropHandlerView.frame.origin.x + translation.x) / self.frame.size.width;
    CGFloat translationX = translation.x;
    if (self.videoCropRightProcess - leftTobe <= self.videoMinPercent) {
        self.videoCropLeftProcess = self.videoCropRightProcess - self.videoMinPercent;
        translationX = self.videoCropRightHandlerImageView.frame.origin.x + self.videoCropRightHandlerImageView.frame.size.width - self.videoMinPercent * self.frame.size.width - self.videoCropLeftHandlerImageView.frame.origin.x;
    } else if (leftTobe < 0.0) {
        self.videoCropLeftProcess = 0.0;
        translationX = -self.videoCropHandlerView.frame.origin.x;
    } else {
        self.videoCropLeftProcess = leftTobe;
    }
    sender.view.center = CGPointMake(sender.view.center.x + translation.x, sender.view.center.y);
    [sender setTranslation:CGPointZero inView:self.videoCropLeftHandlerMaskView];

    // time
    self.videoCropBeginTime = (self.scrollView.contentOffset.x / self.frame.size.width + self.videoCropLeftProcess) * self.timeOfScreenWidth;
    self.videoCropDurationTime = self.videoCropEndTime - self.videoCropBeginTime;
    self.videoCropPreCurTime = self.videoCropBeginTime;
    self.videoCropCurrentTime = self.videoCropBeginTime;

    // update CropHandlerView
    self.videoCropHandlerView.frame = CGRectMake(self.videoCropHandlerView.frame.origin.x + translationX, self.videoCropHandlerView.frame.origin.y, self.videoCropHandlerView.frame.size.width - translationX, self.videoCropHandlerView.frame.size.height);

    // MaskView frame
    self.videoCropLeftHandlerMaskView.frame = CGRectMake(0, 0, self.videoCropHandlerView.frame.origin.x, self.videoCropLeftHandlerMaskView.frame.size.height);
}

#pragma mark - KVO
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (((PLVideoCropView *) object).videoCropHandlerView != self.videoCropHandlerView) {
        return;
    }

    // width of handler
    CGFloat handlerScaleFactor = self.videoCropHandlerView.frame.size.height / 60.0f;
    CGFloat widthOfHandler = handlerScaleFactor * 20.0f;

    // 修正由于滑动手势修改背景frame导致的子view's frame的位置问题
    self.videoCropLeftHandlerImageView.frame = CGRectMake(0, 0, widthOfHandler, self.videoCropHandlerView.frame.size.height);
    self.videoCropRightHandlerImageView.frame = CGRectMake(self.videoCropHandlerView.frame.size.width - widthOfHandler, 0, widthOfHandler, self.videoCropHandlerView.frame.size.height);

    // update VideoPreImage
    if ([_delegate respondsToSelector:@selector(updateVideoPreImage)]) {
        self.videoPlayProgressBar.hidden = YES;
        [_delegate updateVideoPreImage];
    }
}

#pragma mark - UIScrollView delegate

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    // update VideoPreImage
    self.videoCropBeginTime = (self.scrollView.contentOffset.x / self.frame.size.width + self.videoCropLeftProcess) * self.timeOfScreenWidth;
    self.videoCropEndTime = (self.scrollView.contentOffset.x / self.frame.size.width + self.videoCropRightProcess) * self.timeOfScreenWidth;
    self.videoCropDurationTime = self.videoCropEndTime - self.videoCropBeginTime;
    self.videoCropCurrentTime = self.videoCropBeginTime;
    self.videoCropPreCurTime = self.videoCropBeginTime;
    
    if ([_delegate respondsToSelector:@selector(updateVideoPreImage)]) {
        [_delegate updateVideoPreImage];
    }
}

- (void)dealloc
{
    [self removeObserver:self forKeyPath:@"videoCropHandlerView.frame"];
}

@end

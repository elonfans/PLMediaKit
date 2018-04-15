//
//  VideoCropView.h
//  QiuBai
//
//  Created by 小飞 刘 on 15/1/27.
//  Copyright (c) 2015年 Less Everything. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AssetsLibrary/AssetsLibrary.h>
#import <AVFoundation/AVFoundation.h>

#define VIDEO_MIN_DURATION 3
#define VIDEO_MAX_DURATION 300.1
#define VIDEO_THUMB_NUMBER 12

@protocol PLVideoCropViewDelegate <NSObject>
@optional
- (void)updateVideoPreImage;

@end


@interface PLVideoCropView : UIView <UIScrollViewDelegate>

@property (nonatomic, strong) AVAsset *videoAsset;
@property (nonatomic) CGFloat videoDuration;

@property (nonatomic, weak) id<PLVideoCropViewDelegate> delegate;
@property (strong,nonatomic) UIImage *videoPreImage;
@property (strong,nonatomic) UIView *videoPlayProgressBar;

@property (nonatomic) CGFloat videoCropCurrentTime; // 当前播放的时间
@property (nonatomic) CGFloat videoCropPreCurTime;  // 左右拖动，预览界面的时候的time
@property (nonatomic) CGFloat videoCropBeginTime;   // 当前截取视频开始的时间
@property (nonatomic) CGFloat videoCropEndTime;
@property (nonatomic) CGFloat videoCropDurationTime;

- (instancetype)initWithFrame:(CGRect)frame withVideoAsset:(AVAsset *)videoAsset andVideoDuration:(CGFloat)videoDuration;

- (void)setProgressBar:(CGFloat)progress;

@end




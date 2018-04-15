//
//  PLVideoRecorderVC.h
//  QiuBai
//
//  Created by 小飞 刘 on 14/12/23.
//  Copyright (c) 2014年 Less Everything. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "PLVideoRecorder.h"
#import "PLPostArticleAnimationDelegate.h"


/**
 *  用途：视频拍摄界面
 */

// recorder
#define MIN_VIDEO_DUR 3
#define MAX_VIDEO_DUR 300.5 // 视频合成有问题，会删减0.36秒
// recorder btns animation config
#define DURATION 0.1666
#define OFFSETX_OF_INTERVAL_1 40
#define OFFSETX_OF_INTERVAL_2 30
#define SCALE_OF_INTERVAL_1 1.4
#define SCALE_OF_INTERVAL_2 1
// videoEncodeLoadingImageView animation config
#define ENCODELOADINGIMAGEVIEW_ANIMATION_DURATION 1
// Video TipBubble
#define VIDEOFIRSTTIPBUBBLE_JUMP_DURATION 0.5
#define VIDEOTIPBUBBLE_JUMP_DURATION 0.5
// videoRecorderShine
#define VIDEORECORDERSHINE_DURATION 1


@interface PLVideoRecorderVC : UIViewController <PLVideoRecorderDelegate>

@property (nonatomic, weak) id<PLPostArticleAnimationDelegate> delegate;
@property (nonatomic, copy) void (^recordVCDismssCallback)(void);

@end

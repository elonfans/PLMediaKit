//
//  VideoHandlerViewController.h
//  QiuBai
//
//  Created by 小飞 刘 on 15/1/27.
//  Copyright (c) 2015年 Less Everything. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import "PLVideoHandlerViewController.h"
#import <AVFoundation/AVFoundation.h>
#import "PLVideoCropView.h"
#import "PLPostArticleAnimationDelegate.h"

// videoEncodeLoadingImageView animation config
#define ENCODELOADINGIMAGEVIEW_ANIMATION_DURATION 1

@interface PLVideoHandlerViewController : UIViewController <PLVideoCropViewDelegate>

@property (nonatomic, strong) AVAsset *videoAsset;
@property (nonatomic) CGFloat videoDuration;
@property (nonatomic, weak) id<PLPostArticleAnimationDelegate> delegate;
@property (nonatomic, copy) void (^recordVCDismssCallback)(void);

@end

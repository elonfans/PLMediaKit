//
//  PostArticleAnimationDelegate.h
//  QiuBai
//
//  Created by Archmage on 14/12/29.
//  Copyright (c) 2014年 Less Everything. All rights reserved.
//

@protocol PLPostArticleAnimationDelegate <NSObject>

@optional
// 获取缩放动画结束后的rect
- (CGRect)animateEndRect;
// 视频选取，第一帧图片
- (void)onVideoSelectedWithPath:(NSString *)path firstImg:(UIImage *)image videoOriginHash:(NSString*)videoOriginHash;
// 发表图片使用
- (void)onImageSelected:(UIImage *)image;
// 发表图片使用 原始图片，用来获取原始图片的信息
- (void)originalImage:(UIImage *)image imageType:(NSString *)type;

@end

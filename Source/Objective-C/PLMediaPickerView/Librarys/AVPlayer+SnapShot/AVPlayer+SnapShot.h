//
//  AVPlayer+SnapShot.h
//  QiuBai
//
//  Created by noark on 14/12/26.
//  Copyright (c) 2014年 Less Everything. All rights reserved.
//

#import <AVFoundation/AVFoundation.h>

/**
 *  从AVPlayer中获取一帧截图
 */
@interface AVPlayer (SnapShot)

/**
 *  根据时间获取截图
 *
 *  @param aTime      需要的时间
 *  @param actureTime 实际的时间，使用地址传入，调用后返回
 *
 *  @return 截图
 */
- (UIImage *)frameCGImageAtTime:(CMTime)aTime actureTime:(CMTime *)actureTime;

@end

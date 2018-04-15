//
//  AVPlayer+SnapShot.m
//  QiuBai
//
//  Created by noark on 14/12/26.
//  Copyright (c) 2014年 Less Everything. All rights reserved.
//

#import "AVPlayer+SnapShot.h"
#import <UIKit/UIKit.h>

@implementation AVPlayer (SnapShot)

- (UIImage *)frameCGImageAtTime:(CMTime)aTime actureTime:(CMTime *)actureTime
{
    AVAssetImageGenerator *generator = [[AVAssetImageGenerator alloc] initWithAsset:self.currentItem.asset];
    NSError *error;
    CGImageRef cgImage = [generator copyCGImageAtTime:aTime actualTime:actureTime error:&error];
    if (error) {
        if (cgImage) {
            CFRelease(cgImage);
        }
        return nil;
    }
    UIImage *result = [UIImage imageWithCGImage:cgImage];
    return result;
}

@end

//
//  UIImage+KIImage.h
//  QiuBai
//
//  Created by Archmage on 14-4-16.
//  Copyright (c) 2014年 Less Everything. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UIImage (PLKIAdditions)

- (UIImage *)fixOrientation;

/*垂直翻转*/
- (UIImage *)flipVertical;

/*水平翻转*/
- (UIImage *)flipHorizontal;

/*改变size*/
- (UIImage *)resizeToWidth:(CGFloat)width height:(CGFloat)height;

/*裁切*/
- (UIImage *)cropImageWithX:(CGFloat)x y:(CGFloat)y width:(CGFloat)width height:(CGFloat)height;

+ (UIImage *) resizeImage:(UIImage*)img toSize:(CGSize)newSize;
+ (UIImage *) thumbnailImageForVideo:(NSURL *)videoURL atTime:(NSTimeInterval)time;
- (UIImage*)rotate:(UIImageOrientation)orient;
- (UIImage *)leftRightMirrored;

@end

//
//  UIButton+EnLargeEdge.h
//  QiuBai
//
//  Created by 小飞 刘 on 11/3/15.
//  Copyright © 2015 Less Everything. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <objc/runtime.h>

@interface UIButton (PLEnLargeEdge)

- (void)setEnlargeEdge:(CGFloat) size;
- (void)setEnlargeEdgeWithTop:(CGFloat) top right:(CGFloat) right bottom:(CGFloat) bottom left:(CGFloat) left;

@end

//
//  PLVideoCropHanderView.m
//  QiuBai
//
//  Created by 小飞 刘 on 2/2/15.
//  Copyright (c) 2015 Less Everything. All rights reserved.
//

#import "PLVideoCropHanderView.h"

@implementation PLVideoCropHanderView

- (id)hitTest:(CGPoint)point withEvent:(UIEvent *)event
{
    UIView *hitView = [super hitTest:point withEvent:event];
    if (hitView == self){
        return nil;
    } else {
        return hitView;
    }
}

@end

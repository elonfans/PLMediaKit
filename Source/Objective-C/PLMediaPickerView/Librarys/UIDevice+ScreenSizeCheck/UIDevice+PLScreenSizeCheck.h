//
//  UIDevice+PLScreenSizeCheck.h
//  QiuBai
//
//  Created by noark on 14/10/27.
//  Copyright (c) 2014年 Less Everything. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UIDevice (PLScreenSizeCheck)

+ (BOOL)isWideScreenIPhone;

+ (BOOL)isiPhone6;

+ (BOOL)isiPhone6Plus;

@end

extern UIDevice *PLMyDevice(void);

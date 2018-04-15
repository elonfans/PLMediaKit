//
//  Constant.h
//  Demo
//
//  Created by Pauley Liu on 29/08/2017.
//  Copyright © 2017 Pauley Liu. All rights reserved.
//

#ifndef Constant_h
#define Constant_h

#define UIColorFromRGB(rgbValue) \
[UIColor colorWithRed:((float)((rgbValue & 0xFF0000) >> 16))/255.0 \
green:((float)((rgbValue & 0x00FF00) >>  8))/255.0 \
blue:((float)((rgbValue & 0x0000FF) >>  0))/255.0 \
alpha:1.0]
#define RGBA(r,g,b,a) [UIColor colorWithRed:r/255.0f green:g/255.0f blue:b/255.0f alpha:a]
#define RGB(r,g,b) RGBA(r,g,b,1.0f)

#define VIEWSAFEAREAINSETS(view) ({UIEdgeInsets i; if(@available(iOS 11.0, *)) {i = view.safeAreaInsets;} else {i = UIEdgeInsetsZero;} i; })
#define KOSStatusBarHeight [UIApplication sharedApplication].statusBarFrame.size.height //状态栏的高度，iphonex 44pt，其他iphone 20pt

#define VideoSelectBackground 0x1a1a1f
#define VideoSelectNavBackground 0x1a1a1f
#define VideoSelectNavTextBackground 0xffa015
#define VideoSelectNavTitle 0x8f8f95
#define VideoSelectTableViewCellSparate 0x313136
#define VideoSelectNavTextBackground 0xffa015

#define isiPhoneX ([UIScreen mainScreen].bounds.size.width == 375.f && [UIScreen mainScreen].bounds.size.height == 812.f ? YES : NO)
#define safeAreaBottomPadding (isiPhoneX ? 34 : 0)

#endif /* Constant_h */

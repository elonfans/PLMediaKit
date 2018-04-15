//
//  UIDevice+PLPL.h
//  Apollo
//
//  Created by xhan on 10-10-22.
//  Copyright 2010 Baidu.com. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface UIDevice(PLPL)

@property(nonatomic,readonly) BOOL isPLIOS8AndAbove;
@property(nonatomic,readonly) BOOL isPLIOS9AndAbove;
@property(nonatomic,readonly) BOOL isPLIOS10AndAbove;
@property(nonatomic,readonly) BOOL isPLIOS11AndAbove;

- (NSString *)platform;
- (long long)getTotalMemorySize;

@end

extern UIDevice* PLPLMyDevice();

//
//  PLVideoModel.h
//  Demo
//
//  Created by pauley on 25/01/2018.
//  Copyright © 2018 Pauley Liu. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface PLVideoModel : NSObject

@property (nonatomic, strong) NSString *path;   // 视频相对路径路径，Documents路径下
@property (nonatomic, strong) UIImage *image;   // 视频封面
@property (nonatomic, strong) NSString *videoOriginHash;    // 视频哈希值校验值

@end

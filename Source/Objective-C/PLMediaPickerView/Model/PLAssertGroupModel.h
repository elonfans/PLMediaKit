//
//  PLAssertGroupModel.h
//  QiuBai
//
//  Created by 小飞 刘 on 5/26/16.
//  Copyright © 2016 Less Everything. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface PLAssertGroupModel : NSObject

/**
 *  资源
 */
@property (nonatomic, strong) id collection;
/**
 *  标题
 */
@property (nonatomic, strong) NSString *title;
/**
 *  资源数量
 */
@property (nonatomic, strong) NSNumber *count;

@end

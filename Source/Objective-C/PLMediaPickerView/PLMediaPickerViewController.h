//
//  PLMediaPickerViewController.h
//  Demo
//
//  Created by Pauley Liu on 29/08/2017.
//  Copyright © 2017 Pauley Liu. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AssetsLibrary/AssetsLibrary.h>
#import <Photos/Photos.h>
#import "Constant.h"
#import "PLVideoModel.h"

typedef enum : NSUInteger {
    PickerTypeImage,
    PickerTypeVideo,
} PickerType;

typedef void (^ImageCompleteBlock)(NSArray *imagesData);
typedef void (^VideoCompleteBlock)(PLVideoModel *model);
typedef void (^ErrorBlock)(NSError *error);

@interface PLMediaPickerViewController : UINavigationController

@property (nonatomic, assign) PickerType type; // default is PickerTypeImage
@property (nonatomic, assign) NSInteger maxNumber;  // default is 6
@property (nonatomic, copy) NSString *doneBtnName;  // default is "完成"
@property (nonatomic, assign) BOOL dismissWhenComplete; // default is YES
@property (nonatomic, assign) BOOL supportTakePhotoWhenPickerImage; // default is YES
@property (nonatomic, assign) BOOL supportPreview;  // default is YES, if NO can only select one item
@property (nonatomic, assign) BOOL supportAutorotate; // default is NO
@property (nonatomic, assign) BOOL supportTakePhoto; //  default is YES

- (void)callBackImagesData:(ImageCompleteBlock)imageDataComplete error:(ErrorBlock)error;

- (void)callBackVideoModel:(VideoCompleteBlock)VideoModelBlock error:(ErrorBlock)error;

@end

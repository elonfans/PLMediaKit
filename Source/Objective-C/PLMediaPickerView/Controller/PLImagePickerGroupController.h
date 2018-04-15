//
//  PLImagePickerGroupController.h
//  QiuBai
//
//  Created by 小飞 刘 on 9/17/15.
//  Copyright © 2015 Less Everything. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "PLImagePickerController.h"
#import "PLMediaPickerViewController.h"
#import <Photos/Photos.h>

@interface PLImagePickerGroupController : UIViewController

@property (nonatomic) NSInteger maxNumberOfPhotos;
@property (weak,nonatomic) id<PLImagePickerControllerDelegate> delegate;
@property (nonatomic, assign) BOOL dismissWhenComplete; // default is YES
@property (nonatomic, assign) BOOL supportPreview;  // default is YES
@property (nonatomic, assign) PickerType type;
@property (nonatomic, assign) BOOL supportTakePhoto; //  default is YES

@end

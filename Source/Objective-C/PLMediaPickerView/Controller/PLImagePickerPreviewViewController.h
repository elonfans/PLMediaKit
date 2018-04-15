//
//  PLImagePickerPreviewViewController.h
//  QiuBai
//
//  Created by 小飞 刘 on 11/3/15.
//  Copyright © 2015 Less Everything. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "PLImagePickerController.h"

@interface PLImagePickerPreviewViewController : UICollectionViewController

@property (nonatomic) NSInteger maxNumberOfPhotos;      // 最多可选
@property (nonatomic, copy) NSMutableArray *asserts;
@property (nonatomic, strong) NSMutableArray *selectedAsserts;
@property (nonatomic, strong) NSIndexPath *jumpIndexPath;
@property (nonatomic, strong) NSString *doneBtnName;
@property (nonatomic, assign) BOOL isSupportEditWhenSelectSinglePhoto;
@property (nonatomic, weak) PLImagePickerController  *pickerVC;
@property (nonatomic, weak) id<PLImagePickerControllerDelegate> delegate;
@property (nonatomic, assign) BOOL dismissWhenComplete; // default is YES;

@end

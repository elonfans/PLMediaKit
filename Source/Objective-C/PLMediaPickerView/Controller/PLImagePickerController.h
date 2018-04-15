//
//  PLImagePickerController.h
//  
//
//  Created by 小飞 刘 on 9/16/15.
//
//

#import <UIKit/UIKit.h>
#import <AssetsLibrary/AssetsLibrary.h>
#import "PLMediaPickerViewController.h"
#import <Photos/Photos.h>

@protocol PLImagePickerControllerDelegate <NSObject>

@optional
- (void)mediaInfo:(NSArray *)info;
- (void)error:(NSError *)error;

@end

@interface PLImagePickerController : UICollectionViewController

@property (weak,nonatomic) id<PLImagePickerControllerDelegate> delegate;
@property (nonatomic,strong) id assertGroup;
@property (nonatomic) BOOL isSupportEditWhenSelectSinglePhoto;
@property (nonatomic) NSInteger maxNumberOfPhotos;      // 最多可选
@property (nonatomic,strong) NSString *doneBtnName;
@property (nonatomic, assign) BOOL dismissWhenComplete; // default is YES
@property (nonatomic, assign) BOOL supportPreview;  // default is YES
@property (nonatomic, assign) PickerType type;
@property (nonatomic, assign) BOOL supportTakePhoto; //  default is YES

+ (PLImagePickerController *)imagePickerController;

@end

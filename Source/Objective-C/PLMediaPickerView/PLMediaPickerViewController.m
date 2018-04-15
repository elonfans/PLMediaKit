//
//  PLMediaPickerViewController.m
//  Demo
//
//  Created by Pauley Liu on 29/08/2017.
//  Copyright © 2017 Pauley Liu. All rights reserved.
//

#import "PLMediaPickerViewController.h"
#import "PLImagePickerController.h"
#import "PLImagePickerGroupController.h"
#import "UIImage+PLFixOrientation.h"
#import "UIImage+PLExtends.h"
#import <Photos/Photos.h>
#import "MBProgressHUD.h"
#import "PLAssertManager.h"
#import "UIImage+animatedGIF.h"
#import <Photos/Photos.h>

@interface PLMediaPickerViewController () <PLImagePickerControllerDelegate>

@property (nonatomic, copy) ImageCompleteBlock imageComplete;
@property (nonatomic, copy) VideoCompleteBlock videoComplete;
@property (nonatomic, copy) ErrorBlock error;
@property (nonatomic, assign) BOOL callBackAssets;
@property (nonatomic, strong) PLImagePickerController *pickerVC;
@property (nonatomic, strong) PLImagePickerGroupController *pickerGroupVC;

@end

@implementation PLMediaPickerViewController

- (void)dealloc
{
    NSLog(@"dealloc === PLMediaPickerViewController");
}

- (instancetype)init
{
    if (self = [super init]) {
        self.dismissWhenComplete = YES;
        self.maxNumber = 6;
        self.supportPreview = YES;
        self.supportAutorotate = NO;
        self.supportTakePhoto = YES;
        self.type = PickerTypeImage;
        
        [self setup];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
}

- (void)setup
{
    self.pickerVC.isSupportEditWhenSelectSinglePhoto = NO;
    self.pickerVC.delegate = self;
    self.pickerVC.doneBtnName = @"完成";
    
    self.pickerGroupVC.delegate = self;
    
    NSMutableArray *vcArr = [NSMutableArray arrayWithCapacity:0];
    if (self.pickerGroupVC) {
        [vcArr addObject:self.pickerGroupVC];
    }
    if (self.pickerVC) {
        [vcArr addObject:self.pickerVC];
    }
    self.viewControllers = vcArr;
}

- (void)setDismissWhenComplete:(BOOL)dismissWhenComplete
{
    _dismissWhenComplete = dismissWhenComplete;
    
    self.pickerVC.dismissWhenComplete = dismissWhenComplete;
    self.pickerGroupVC.dismissWhenComplete = dismissWhenComplete;
}

- (void)callBackAsssets:(ImageCompleteBlock)complete error:(ErrorBlock)error
{
    self.callBackAssets = YES;
    self.imageComplete = complete;
    self.error = error;
}

- (void)callBackImagesData:(ImageCompleteBlock)imageDataComplete error:(ErrorBlock)error
{
    self.imageComplete = imageDataComplete;
    self.callBackAssets = NO;
    self.error = error;
}

- (void)callBackVideoModel:(VideoCompleteBlock)VideoModelBlock error:(ErrorBlock)error
{
    self.videoComplete = VideoModelBlock;
    self.error = error;
}

- (void)setDoneBtnName:(NSString *)doneBtnName
{
    self.pickerVC.doneBtnName = doneBtnName;
}

- (void)setMaxNumber:(NSInteger)maxNumber
{
    _maxNumber = maxNumber;
    self.pickerGroupVC.maxNumberOfPhotos = maxNumber;
    self.pickerVC.maxNumberOfPhotos = maxNumber;
}

- (void)setSupportPreview:(BOOL)supportPreview
{
    _supportPreview = supportPreview;
    self.pickerVC.supportPreview = self.supportPreview;
    self.pickerGroupVC.supportPreview = self.supportPreview;
}

- (void)setSupportTakePhoto:(BOOL)supportTakePhoto
{
    _supportTakePhoto = supportTakePhoto;
    self.pickerVC.supportTakePhoto = self.supportTakePhoto;
    self.pickerGroupVC.supportTakePhoto = self.supportTakePhoto;
}

- (void)setType:(PickerType)type
{
    _type = type;
    self.pickerVC.type = type;
    self.pickerGroupVC.type = type;
}

#pragma mark - getter

- (PLImagePickerGroupController *)pickerGroupVC
{
    if (!_pickerGroupVC) {
        _pickerGroupVC = [[PLImagePickerGroupController alloc] init];
    }
    return _pickerGroupVC;
}

- (PLImagePickerController *)pickerVC
{
    if (!_pickerVC) {
        _pickerVC = [PLImagePickerController imagePickerController];
    }
    return _pickerVC;
}

#pragma mark - PLImagePickerControllerDelegate

- (void)mediaInfo:(NSArray *)info
{
    // video
    if (info.count == 1) {
        if ([[info firstObject] isKindOfClass:[PLVideoModel class]]) {
            if (self.videoComplete) {
                self.videoComplete([info firstObject]);
                return;
            }
        }
    }
    
    // image
    if (self.imageComplete) {
        if (self.callBackAssets) {
            self.imageComplete(info);
        } else {
            NSMutableArray *array = [NSMutableArray array];
            __block NSInteger failureCount = 0;
            
            //转菊花
            MBProgressHUD *hud;
            if (!hud) {
                hud = [[MBProgressHUD alloc] initWithWindow:[UIApplication sharedApplication].delegate.window];
                hud.tag = 101;
                hud.mode = MBProgressHUDModeIndeterminate;
                hud.labelText = @"图片处理中";
                [hud removeFromSuperViewOnHide];
                [[UIApplication sharedApplication].delegate.window addSubview:hud];
                if ([hud respondsToSelector:@selector(hide:)]) {
                    [hud hide:YES];
                }
            } else {
                hud = [[UIApplication sharedApplication].delegate.window viewWithTag:101];
                hud.mode = MBProgressHUDModeIndeterminate;
                hud.labelText = @"图片处理中";
            }
            [hud show:YES];
            
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                for (int i = 0; i < info.count; i++) {
                    id item = info[i];
                    if ([item isKindOfClass:[UIImage class]]) {
                        //拍照
                        @autoreleasepool {
                            UIImage *compressedImage = [item compressImageWithRotate:NO];
                            [array addObject:UIImageJPEGRepresentation(compressedImage, 1.0)];
                            dispatch_async(dispatch_get_main_queue(), ^{
                                self.imageComplete(array);
                                [hud hide:YES];
                            });
                        }
                    } else if ([item isKindOfClass:[PHAsset class]]) {
                        //相册选图
                        PHAsset *asset = info[i];
                        dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
                        [PLAssertManager assertImage:asset size:CGSizeZero usingDataBlock:^(NSData *imageData, BOOL isGif) {
                            dispatch_async(dispatch_get_main_queue(), ^{
                                if (imageData) {
                                    [array addObject:imageData];
                                } else {
                                    failureCount += 1;
                                }
                                if (array.count == info.count - failureCount) {
                                    if (failureCount > 0) {
                                        if ([hud respondsToSelector:@selector(hide:)]) {
                                            hud.mode = MBProgressHUDModeText;
                                            if (info.count == 1 && failureCount == 1) {
                                                hud.labelText = @"这张图片太大了";
                                            } else {
                                                hud.labelText = [NSString stringWithFormat:@"有%@张图片太大了", @(failureCount)];
                                            }
                                            [hud hide:YES afterDelay:2];
                                        }
                                    } else {
                                        [hud hide:YES];
                                    }
                                    self.imageComplete(array);
                                }
                            });
                            dispatch_semaphore_signal(semaphore);
                        } isNeedCompressed:YES];
                        dispatch_semaphore_wait(semaphore,DISPATCH_TIME_FOREVER);
                    }
                }
            });
        }
    }
}

- (void)error:(NSError *)error
{
    self.error(error);
}

- (BOOL)shouldAutorotate
{
    return self.supportAutorotate;
}

@end


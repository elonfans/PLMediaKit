//
//  PLImagePickerController.m
//
//
//  Created by 小飞 刘 on 9/16/15.
//
//

#import "PLImagePickerController.h"
#import "PLImagePickerGroupController.h"
#import "PLImagePickerCell.h"
#import "PLImagePickerTakePhotoCell.h"
#import "UIImage+PLExtends.h"
#import "PLImagePickerPreviewViewController.h"
#import <POP.h>
#import "POPSpringAnimation.h"
#import "PLUIHelper.h"
#import "PLAssertManager.h"
#import <AssetsLibrary/AssetsLibrary.h>
#import <AVFoundation/AVFoundation.h>
#import <Photos/Photos.h>
#import "PLPLAlertView.h"
#import "UIDevice+PLPL.h"
#import "UIImage+PLFixOrientation.h"
#import "Constant.h"
#import "PLVideoHandlerViewController.h"
#import "PLVideoRecorderVC.h"
#import "PLVideoModel.h"
#import <CommonCrypto/CommonDigest.h>

#define BottomBarHeight 45

@interface PLImagePickerController ()<UICollectionViewDelegate, UICollectionViewDataSource, UIImagePickerControllerDelegate, PLImagePickerCellDelegate, PHPhotoLibraryChangeObserver, PLPostArticleAnimationDelegate>

@property (nonatomic, assign) CGSize cellSize;
@property (nonatomic, assign) CGFloat cellSpacing;
@property (nonatomic, assign) CGFloat selectionSpacing;
@property (nonatomic, strong) UICollectionView *photosCollectionView;
@property (nonatomic, strong) NSArray *sectionFetchResults;
@property (nonatomic, strong) PLAssertManager *assertModel;
@property (nonatomic, strong) ALAssetsLibrary *assetsLibrary;
@property (nonatomic, strong) NSMutableArray *groups;
@property (nonatomic, strong) NSMutableArray *asserts;
@property (nonatomic, strong) UIButton *bottomBarLeftBtn;
@property (nonatomic, strong) UIButton *bottomBarRightBtn;
@property (nonatomic, strong) UILabel *bottomBarSelectedLabel;
@property (nonatomic, strong) NSMutableArray *selectedAsserts;
@property (nonatomic, strong) UIView *bottomToolBarView;

@end

@implementation PLImagePickerController

static NSString * const reuseIdentifier = @"Cell";

- (void)dealloc
{
    [[PHPhotoLibrary sharedPhotoLibrary] unregisterChangeObserver:self];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

+ (PLImagePickerController *)imagePickerController
{
    PLImagePickerController *vc = nil;
    ALAuthorizationStatus author = [ALAssetsLibrary authorizationStatus];
    
    // 此应用程序没有被授权访问的照片数据。可能是家长控制权限 || 用户已经明确否认了这一照片数据的应用程序访问
    if(author == ALAuthorizationStatusRestricted || author == ALAuthorizationStatusDenied){
        //无权限
        PLPLAlert(@"您现在无法使用照片功能，解除封印的办法是：点击“去设置”，点击“隐私”，点击“照片”，打开“糗事百科”设置项。", nil, @"取消", @"去设置", ^(int index, BOOL isCancel) {
            if (!isCancel)
                [[UIApplication sharedApplication] openURL:[NSURL URLWithString:UIApplicationOpenSettingsURLString]];
        });
    }
    
    UICollectionViewFlowLayout *layout= [[UICollectionViewFlowLayout alloc]init];
    [layout setScrollDirection:UICollectionViewScrollDirectionVertical];
    vc = [[PLImagePickerController alloc] initWithCollectionViewLayout:layout];
    
    return vc;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
}

- (void)loadAssert
{
    self.assertModel = [PLAssertManager new];
    
    __weak typeof(self) weakSelf = self;
    [self.assertModel assertForType:_type assertsGroup:self.assertGroup block:^(NSArray *currentGroupAssertsArray) {
        dispatch_async(dispatch_get_main_queue(), ^{
            weakSelf.assertModel.currentGroupAsserts = [NSMutableArray arrayWithArray:currentGroupAssertsArray];
            [weakSelf.collectionView reloadData];
        });
    }];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.view.backgroundColor = UIColorFromRGB(VideoSelectBackground);
    
    if (!self.title) {
        if (self.type == PickerTypeImage) {
            self.title = @"选择照片";
        } else if (self.type == PickerTypeVideo) {
            self.title = @"选择视频";
        }
    }
    
    if (!self.doneBtnName) {
        self.doneBtnName = @"完成";
    }
    
    [self setNavigationBar];
    
    if (self.supportPreview) {
        [self setBottomToolBar];
    }
    if (self.type == PickerTypeImage) {
        self.bottomToolBarView.hidden = NO;
    } else {
        self.bottomToolBarView.hidden = YES;
    }
    
    if (!self.selectedAsserts) {
        self.selectedAsserts = [[NSMutableArray alloc] init];
    }
    
    self.collectionView.delegate = self;
    self.collectionView.dataSource = self;
    self.collectionView.backgroundColor = UIColorFromRGB(VideoSelectBackground);
    self.collectionView.showsHorizontalScrollIndicator = NO;
    self.collectionView.showsVerticalScrollIndicator = NO;
    self.cellSpacing = 5;
    self.selectionSpacing = 3;
    NSInteger cellNumberInSingleLine = 4;
    if ([UIScreen mainScreen].bounds.size.width < 375) {
        cellNumberInSingleLine = 3;
    }
    CGFloat cellWidth = (self.view.frame.size.width - self.cellSpacing * 3 - self.selectionSpacing * 2) / cellNumberInSingleLine;
    self.cellSize = CGSizeMake(cellWidth, cellWidth);
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(userDidTakeScreenshot:)
                                                 name:UIApplicationUserDidTakeScreenshotNotification object:nil];
    
    [self.collectionView registerClass:[PLImagePickerTakePhotoCell class] forCellWithReuseIdentifier:@"identifierT"];
    [self.collectionView registerClass:[PLImagePickerCell class] forCellWithReuseIdentifier:@"identifier"];

    [[PHPhotoLibrary sharedPhotoLibrary] registerChangeObserver:self];
    
    if ([PHPhotoLibrary authorizationStatus] == PHAuthorizationStatusDenied) {
        [self returnErrorMsg:@"相册权限已关闭，请在设置中打开后再操作"];
    } else if ([PHPhotoLibrary authorizationStatus] == PHAuthorizationStatusRestricted) {
        [self returnErrorMsg:@"家长控制,不允许访问"];
    } else if ([PHPhotoLibrary authorizationStatus] == PHAuthorizationStatusAuthorized) {
        [self loadAssert];
    }
}

- (void)viewWillDisappear:(BOOL)animated
{
    if ([[UIDevice currentDevice] respondsToSelector:@selector(setOrientation:)]) {
        SEL selector = NSSelectorFromString(@"setOrientation:");
        NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:[UIDevice instanceMethodSignatureForSelector:selector]];
        [invocation setSelector:selector];
        [invocation setTarget:[UIDevice currentDevice]];
        int val = UIInterfaceOrientationPortrait;
        [invocation setArgument:&val atIndex:2];
        [invocation invoke];
    }
}

- (void)viewSafeAreaInsetsDidChange
{
    [super viewSafeAreaInsetsDidChange];
    if (@available(iOS 11, *)) {
        self.collectionView.frame = CGRectMake(self.view.safeAreaInsets.left,
                                               self.view.safeAreaInsets.top,
                                               CGRectGetWidth(self.view.frame) - self.view.safeAreaInsets.left - self.view.safeAreaInsets.right,
                                               CGRectGetHeight(self.view.frame) - self.view.safeAreaInsets.top - self.view.safeAreaInsets.bottom);
    }
}

#pragma mark -- Private Method

- (void)setNavigationBar
{
    self.navigationController.navigationBar.barTintColor = UIColorFromRGB(VideoSelectNavBackground);
    self.navigationController.navigationBar.tintColor = [UIColor whiteColor];
    [self.navigationController.navigationBar setTitleTextAttributes:@{NSForegroundColorAttributeName : UIColorFromRGB(VideoSelectNavTitle)}];
    
    // back btn
    UIButton *leftBarBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    leftBarBtn.titleLabel.font = [PLUIHelper fontWithSize:17.0f];
    [leftBarBtn setTitle:@"相册" forState:UIControlStateNormal];
    [leftBarBtn setTitleColor:UIColorFromRGB(VideoSelectNavTextBackground) forState:UIControlStateNormal];
    [leftBarBtn sizeToFit];
    [leftBarBtn addTarget:self action:@selector(leftBarBtnPressed) forControlEvents:UIControlEventTouchUpInside];
    UIBarButtonItem *leftBarItem = [[UIBarButtonItem alloc] initWithCustomView:leftBarBtn];
    self.navigationItem.leftBarButtonItem = leftBarItem;
    
    // cancel btn
    UIButton *rightBarBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    rightBarBtn.titleLabel.font = [PLUIHelper fontWithSize:17.0f];
    [rightBarBtn setTitle:@"取消" forState:UIControlStateNormal];
    [rightBarBtn setTitleColor:UIColorFromRGB(VideoSelectNavTextBackground) forState:UIControlStateNormal];
    [rightBarBtn sizeToFit];
    [rightBarBtn addTarget:self action:@selector(rightBarBtnPressed) forControlEvents:UIControlEventTouchUpInside];
    UIBarButtonItem *rightBarItem = [[UIBarButtonItem alloc] initWithCustomView:rightBarBtn];
    self.navigationItem.rightBarButtonItem = rightBarItem;
}

- (void)leftBarBtnPressed
{
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)rightBarBtnPressed
{
    [self dismissViewControllerAnimated:YES completion:^(void){}];
}

- (void)setBottomToolBar
{
    if (!self.bottomToolBarView) {
        self.bottomToolBarView = [[UIView alloc] initWithFrame:CGRectMake(0, self.collectionView.frame.size.height - (BottomBarHeight + safeAreaBottomPadding), [UIScreen mainScreen].bounds.size.width, BottomBarHeight + safeAreaBottomPadding)];
        self.bottomToolBarView.backgroundColor = [UIColor blackColor];
        self.bottomToolBarView.alpha = 0.8;
        [self.view addSubview:self.bottomToolBarView];
    }
    
    if (!self.bottomBarLeftBtn) {
        self.bottomBarLeftBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        self.bottomBarLeftBtn.frame = CGRectMake(0,0, 100, self.bottomToolBarView.frame.size.height - safeAreaBottomPadding);
        [self.bottomBarLeftBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        self.bottomBarLeftBtn.titleLabel.font = [PLUIHelper fontWithSize:15.0f];
        self.bottomBarLeftBtn.titleLabel.textAlignment = NSTextAlignmentCenter;
        [self.bottomBarLeftBtn addTarget:self action:@selector(bottomBarLeftBtnPressed) forControlEvents:UIControlEventTouchUpInside];
        [self.bottomBarLeftBtn setTitle:@"预览" forState:UIControlStateNormal];
        [self.bottomToolBarView addSubview:self.bottomBarLeftBtn];
        [self.bottomBarLeftBtn setEnabled:NO];
    }
    
    if (!self.bottomBarRightBtn) {
        self.bottomBarRightBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        self.bottomBarRightBtn.frame = CGRectMake(self.bottomToolBarView.frame.size.width - 100, 0, 100, self.bottomToolBarView.frame.size.height - safeAreaBottomPadding);
        [self.bottomBarRightBtn setTitleColor:UIColorFromRGB(VideoSelectNavTextBackground) forState:UIControlStateNormal];
        self.bottomBarRightBtn.titleLabel.font = [PLUIHelper fontWithSize:15.0f];
        self.bottomBarRightBtn.contentEdgeInsets = UIEdgeInsetsMake(0, 25, 0, 0);
        self.bottomBarRightBtn.titleLabel.textAlignment = NSTextAlignmentCenter;
        [self.bottomBarRightBtn addTarget:self action:@selector(bottomBarRightBtnPressed) forControlEvents:UIControlEventTouchUpInside];
        [self.bottomBarRightBtn setTitle:self.doneBtnName forState:UIControlStateNormal];
        [self.bottomToolBarView addSubview:self.bottomBarRightBtn];
    }
    
    if (!self.bottomBarSelectedLabel) {
        self.bottomBarSelectedLabel = [[UILabel alloc] initWithFrame:CGRectMake(self.bottomToolBarView.frame.size.width - 78,self.bottomToolBarView.frame.size.height / 2 - 20 / 2 - safeAreaBottomPadding / 2, 20, 20)];
        self.bottomBarSelectedLabel.textColor = [UIColor whiteColor];
        self.bottomBarSelectedLabel.backgroundColor = UIColorFromRGB(0xffa015);
        self.bottomBarSelectedLabel.font = [PLUIHelper fontWithSize:13.0f];
        self.bottomBarSelectedLabel.clipsToBounds = YES;
        self.bottomBarSelectedLabel.layer.cornerRadius = self.bottomBarSelectedLabel.frame.size.width / 2;
        self.bottomBarSelectedLabel.textAlignment = NSTextAlignmentCenter;
        [self.bottomToolBarView addSubview:self.bottomBarSelectedLabel];
    }
    
    self.bottomBarSelectedLabel.text = [NSString stringWithFormat:@"%ld",(long)self.selectedAsserts.count];
    if (self.selectedAsserts.count > 0) {
        self.bottomBarSelectedLabel.hidden = NO;
        self.bottomBarLeftBtn.enabled = YES;
    } else {
        self.bottomBarSelectedLabel.hidden = YES;
        UIView *rightBtnMaskView = [[UIView alloc] initWithFrame:self.bottomBarRightBtn.bounds];
        [rightBtnMaskView setBackgroundColor:[UIColor blackColor]];
        rightBtnMaskView.alpha = 0.3;
        self.bottomBarLeftBtn.enabled = NO;
    }
}

- (void)bottomBarLeftBtnPressed
{
    // 预览
    UICollectionViewFlowLayout *layout= [[UICollectionViewFlowLayout alloc]init];
    [layout setScrollDirection:UICollectionViewScrollDirectionHorizontal];
    PLImagePickerPreviewViewController *preViewController = [[PLImagePickerPreviewViewController alloc] initWithCollectionViewLayout:layout];
    preViewController.hidesBottomBarWhenPushed = YES;
    preViewController.title = @"预览";
    preViewController.maxNumberOfPhotos = self.maxNumberOfPhotos;
    preViewController.selectedAsserts = self.selectedAsserts;
    preViewController.asserts = [self.selectedAsserts mutableCopy];
    preViewController.delegate = self.delegate;
    preViewController.pickerVC = self;
    preViewController.dismissWhenComplete = self.dismissWhenComplete;
    preViewController.doneBtnName = self.doneBtnName;
    preViewController.isSupportEditWhenSelectSinglePhoto = self.isSupportEditWhenSelectSinglePhoto;
    [self.navigationController pushViewController:preViewController animated:YES];
}

- (void)bottomBarRightBtnPressed
{
    // 没有选图片不添加
    if (!self.selectedAsserts || self.selectedAsserts.count == 0) {
        [self dismissViewControllerAnimated:YES completion:^{
        }];
        return;
    }
    
    if ([_delegate respondsToSelector:@selector(mediaInfo:)]) {
        [_delegate mediaInfo:self.selectedAsserts];
        
        if (self.dismissWhenComplete) {
            [self dismissViewControllerAnimated:YES completion:nil];
        }
    }
}

- (NSMutableArray*)asserts
{
    if (!_asserts) {
        _asserts = [NSMutableArray new];
    }
    return _asserts;
}

- (void)returnErrorMsg:(NSString *)msg
{
    NSDictionary *userInfo = [NSDictionary dictionaryWithObject:msg forKey:NSLocalizedDescriptionKey];
    NSError *error = [[NSError alloc] initWithDomain:msg code:-1 userInfo:userInfo];
    if ([self.delegate respondsToSelector:@selector(error)]) {
        [self.delegate error:error];
    }
}

#pragma mark <UICollectionViewDataSource>

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView
{
    return 1;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    NSInteger cnt = self.assertModel.currentGroupAsserts.count;
    if (self.supportTakePhoto) {
        cnt++;
    }
    return cnt;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    if (self.supportTakePhoto && indexPath.row == 0) {
        PLImagePickerTakePhotoCell *cell = (PLImagePickerTakePhotoCell *)[collectionView dequeueReusableCellWithReuseIdentifier:@"identifierT" forIndexPath:indexPath];
        cell.pickerType = self.type;
        return cell;
    }
    
    NSInteger index = indexPath.row;
    if (self.supportTakePhoto) {
        index--;
    }
    
    PHAsset *asset = self.assertModel.currentGroupAsserts[index];
    PLImagePickerCell *cell = (PLImagePickerCell *)[collectionView dequeueReusableCellWithReuseIdentifier:@"identifier" forIndexPath:indexPath];
    if (![PLAssertManager isEqulAssert:asset nextAssert:cell.currentAsset]) {
        [cell bindData:asset supportPreview:self.supportPreview];
    }
    cell.delegate = self;
    
    BOOL isAssetExist = NO;
    for (id selectAsset in self.selectedAsserts) {
        if ([PLAssertManager isEqulAssert:selectAsset nextAssert:asset]) {
            isAssetExist = YES;
            break;
        }
    }
    
    if (isAssetExist) {
        [cell.selectedTagBtn setSelected:YES];
    } else {
        [cell.selectedTagBtn setSelected:NO];
    }
    
    return cell;
}

#pragma mark <UICollectionViewDelegate>

- (CGFloat)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout minimumLineSpacingForSectionAtIndex:(NSInteger)section
{
    return self.cellSpacing;
}
- (CGFloat)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout minimumInteritemSpacingForSectionAtIndex:(NSInteger)section
{
    return self.cellSpacing;
}

-(UIEdgeInsets)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout insetForSectionAtIndex:(NSInteger)section
{
    return UIEdgeInsetsMake(9,self.selectionSpacing,BottomBarHeight + safeAreaBottomPadding,self.selectionSpacing);//分别为上、左、下(+底部bar高度)、右
}

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath
{
    return self.cellSize;
}

-(BOOL)collectionView:(UICollectionView *)collectionView shouldSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    return YES;
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.row == 0 && self.supportTakePhoto) {
        if (self.selectedAsserts.count == self.maxNumberOfPhotos) {
            // 超过范围
            NSString *tip = [NSString stringWithFormat:@"最多只能选取%ld张图片哦",(long)self.maxNumberOfPhotos];
            [self returnErrorMsg:tip];
            return;
        } else {
            if (self.type == PickerTypeImage) {
                // 拍照
                [self onTakePhotos:UIImagePickerControllerSourceTypeCamera];
            } else if (self.type == PickerTypeVideo) {
                // 拍视频
                PLVideoRecorderVC *vc = [[PLVideoRecorderVC alloc] initWithNibName:@"PLVideoRecorderVC" bundle:[NSBundle mainBundle]];
                vc.delegate = self;
                [self presentViewController:vc animated:YES completion:nil];
            }
            return;
        }
    } else {
        NSInteger index = indexPath.row;
        if (self.supportTakePhoto) {
            index--;
        }
        
        if (self.supportPreview) {
            PHAsset *asset = self.assertModel.currentGroupAsserts[index];
            if (asset.mediaType == PHAssetMediaTypeImage) {
                UICollectionViewFlowLayout *layout= [[UICollectionViewFlowLayout alloc]init];
                [layout setScrollDirection:UICollectionViewScrollDirectionHorizontal];
                PLImagePickerPreviewViewController *preViewController = [[PLImagePickerPreviewViewController alloc] initWithCollectionViewLayout:layout];
                preViewController.hidesBottomBarWhenPushed = YES;
                preViewController.title = @"预览";
                preViewController.maxNumberOfPhotos = self.maxNumberOfPhotos;
                preViewController.selectedAsserts = self.selectedAsserts;
                preViewController.asserts = self.assertModel.currentGroupAsserts;
                preViewController.jumpIndexPath = [NSIndexPath indexPathForRow:index inSection:0];
                preViewController.delegate = self.delegate;
                preViewController.pickerVC = self;
                preViewController.doneBtnName = self.doneBtnName;
                preViewController.dismissWhenComplete = self.dismissWhenComplete;
                preViewController.isSupportEditWhenSelectSinglePhoto = self.isSupportEditWhenSelectSinglePhoto;
                [self.navigationController pushViewController:preViewController animated:YES];
            } else if (asset.mediaType == PHAssetMediaTypeVideo) {
                PLImagePickerCell *cell = (PLImagePickerCell *)[collectionView cellForItemAtIndexPath:indexPath];
                
                PHVideoRequestOptions *options = [[PHVideoRequestOptions alloc] init];
                options.version = PHVideoRequestOptionsVersionOriginal;
                options.deliveryMode = PHVideoRequestOptionsDeliveryModeAutomatic;
                options.networkAccessAllowed = true; // iCloud的相册需要网络许可
                
                [cell startLoading];
                
                PHImageManager *manager = [PHImageManager defaultManager];
                [manager requestAVAssetForVideo:asset options:options resultHandler:^(AVAsset * _Nullable asset, AVAudioMix * _Nullable audioMix, NSDictionary * _Nullable info) {                    dispatch_async(dispatch_get_main_queue(), ^{
                        
                        [cell stopLoading];
                    
                        if (asset) {
                            PLVideoHandlerViewController *vc = [[PLVideoHandlerViewController alloc] initWithNibName:@"PLVideoHandlerViewController" bundle:[NSBundle mainBundle]];
                            vc.videoDuration = CMTimeGetSeconds(asset.duration);
                            vc.videoAsset = asset;
                            vc.delegate = self;
                            [self.navigationController pushViewController:vc animated:YES];
                        } else {
                            // 用户网络异常，无法同步icloud视频
                            [self returnErrorMsg:@"iCloud同步失败，请稍后重试"];
                        }
                    
                    });
                }];
            }
        } else {
            if ([_delegate respondsToSelector:@selector(mediaInfo:)]) {
                
                [self.selectedAsserts removeAllObjects];
                id asset = self.assertModel.currentGroupAsserts[index];
                [self.selectedAsserts addObject:asset];
                
                [_delegate mediaInfo:self.selectedAsserts];
                
                if (self.dismissWhenComplete) {
                    [self dismissViewControllerAnimated:YES completion:nil];
                }
            }
        }
    }
}

- (void)onTakePhotos:(UIImagePickerControllerSourceType)type
{
    AVAuthorizationStatus authStatus = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
    if (authStatus == AVAuthorizationStatusDenied || AVAuthorizationStatusRestricted == authStatus){// have no permission
        PLPLAlert(@"您现在无法使用相机功能，解除封印的办法是：点击“去设置”，打开“相机”设置项。", nil, @"取消", @"去设置", ^(int index, BOOL isCancel) {
            if (!isCancel)
                [[UIApplication sharedApplication] openURL:[NSURL URLWithString:UIApplicationOpenSettingsURLString]];
        });
    }
    
    BOOL sourceCamera = UIImagePickerControllerSourceTypeCamera == type && [UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera];
    
    UIImagePickerController *pickerVC = [[UIImagePickerController alloc] init];
    pickerVC.sourceType = sourceCamera ? UIImagePickerControllerSourceTypeCamera : UIImagePickerControllerSourceTypePhotoLibrary ;
    pickerVC.delegate = (id)self;
    [self presentViewController:pickerVC animated:NO completion:nil];
    
}

#pragma mark - UIImagePickerController Delegate Methods

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info
{
    UIImage *image = [info valueForKey:UIImagePickerControllerOriginalImage];
    if (!image) {
        image = [info valueForKey:UIImagePickerControllerEditedImage];
    }
    image = [image fixOrientation];
    image = [image compressImageWithRotate:NO];
    
    if (image) {
        if ([_delegate respondsToSelector:@selector(mediaInfo:)]) {
            [_delegate mediaInfo:@[image]];
        }
    } else {
        if ([_delegate respondsToSelector:@selector(error:)]) {
            NSDictionary *userInfo1 = [NSDictionary dictionaryWithObjectsAndKeys:@"拍摄照片失败，请重试！", NSLocalizedDescriptionKey, @"失败原因：未知错误", NSLocalizedFailureReasonErrorKey, @"恢复建议：请重新拍摄",NSLocalizedRecoverySuggestionErrorKey,nil];
            NSError *err = [NSError errorWithDomain:NSCocoaErrorDomain code:-1 userInfo:userInfo1];
            [_delegate error:err];
        }
    }
    
    if (self.dismissWhenComplete) {
        [self dismissViewControllerAnimated:YES completion:nil];
        [self.navigationController dismissViewControllerAnimated:YES completion:nil];
    } else {
        [self dismissViewControllerAnimated:NO completion:nil];
    }
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker
{
    [picker dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - Rotation

// ios 6 supports
- (UIInterfaceOrientationMask)supportedInterfaceOrientations
{
    return (1 << UIInterfaceOrientationPortrait);
}

- (BOOL)shouldAutorotate
{
    return NO;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return NO;
}

#pragma mark -- Cell Delegate

- (void)selectedAsset:(PHAsset *)asset cell:(PLImagePickerCell*)cell;
{
    if (self.selectedAsserts.count == self.maxNumberOfPhotos && (!cell.selectedTagBtn.isSelected)) {
        // 超过范围
        NSString *tip = [NSString stringWithFormat:@"最多只能选取%ld张图片哦",(long)self.maxNumberOfPhotos];
        [self returnErrorMsg:tip];
        return;
    }
    
    BOOL isAssetExist = NO;
    ALAsset *assetNeedRemove;
    for (id selectAsset in self.selectedAsserts) {
        if ([PLAssertManager isEqulAssert:selectAsset nextAssert:asset]) {
            isAssetExist = YES;
            assetNeedRemove = selectAsset;
            [self.selectedAsserts removeObject:selectAsset];
            break;
        }
    }
    
    if (assetNeedRemove) {
        [self.selectedAsserts removeObject:assetNeedRemove];
    }
    
    if (isAssetExist) {
        [cell.selectedTagBtn setSelected:NO];
    } else {
        [self.selectedAsserts addObject:asset];
        [cell.selectedTagBtn setSelected:YES];
        
        POPSpringAnimation *sizeAnimation = [POPSpringAnimation animationWithPropertyNamed:kPOPLayerScaleXY];
        sizeAnimation.fromValue = [NSValue valueWithCGSize:CGSizeMake(0.6, 0.6)];
        sizeAnimation.toValue = [NSValue valueWithCGSize:CGSizeMake(1,1)];
        sizeAnimation.springSpeed = 20.f;
        sizeAnimation.springBounciness = 20.0f;
        [cell.selectedTagBtn.layer pop_addAnimation:sizeAnimation forKey:@"paulery"];
    }
    
    if (self.selectedAsserts.count > 0) {
        [self.bottomBarLeftBtn setEnabled:YES];
    } else {
        UIView *rightBtnMaskView = [[UIView alloc] initWithFrame:self.bottomBarRightBtn.bounds];
        [rightBtnMaskView setBackgroundColor:[UIColor blackColor]];
        rightBtnMaskView.alpha = 0.3;
        self.bottomBarLeftBtn.enabled = NO;
    }
    if (self.selectedAsserts.count > 0) {
        self.bottomBarSelectedLabel.text = [NSString stringWithFormat:@"%ld",(long)self.selectedAsserts.count];
        self.bottomBarSelectedLabel.hidden = NO;
        POPSpringAnimation *sizeAnimation = [POPSpringAnimation animationWithPropertyNamed:kPOPLayerScaleXY];
        sizeAnimation.fromValue = [NSValue valueWithCGSize:CGSizeMake(0.6, 0.6)];
        sizeAnimation.toValue = [NSValue valueWithCGSize:CGSizeMake(1,1)];
        sizeAnimation.springSpeed = 20.f;
        sizeAnimation.springBounciness = 20.0f;
        [self.bottomBarSelectedLabel.layer pop_addAnimation:sizeAnimation forKey:@"paulery"];
    } else {
        self.bottomBarSelectedLabel.hidden = YES;
    }
}

- (void)callBackVideoPath:(NSString *)path firstImg:(UIImage *)image videoOriginHash:(NSString *)videoOriginHash
{
    if ([self.delegate respondsToSelector:@selector(mediaInfo:)]) {
        PLVideoModel *videoModel = [[PLVideoModel alloc] init];
        videoModel.path = path;
        videoModel.image = image;
        videoModel.videoOriginHash = videoOriginHash;
        [self.delegate mediaInfo:@[videoModel]];
    }
}

#pragma mark - PLPostArticleAnimationDelegate

// 视频选取，第一帧图片
- (void)onVideoSelectedWithPath:(NSString *)path firstImg:(UIImage *)image videoOriginHash:(NSString *)videoOriginHash
{
    [self callBackVideoPath:path firstImg:image videoOriginHash:videoOriginHash];
    
    if (self.dismissWhenComplete) {
        [self dismissViewControllerAnimated:YES completion:nil];
        [self.navigationController dismissViewControllerAnimated:YES completion:nil];
    } else {
        [self dismissViewControllerAnimated:NO completion:nil];
    }
}

#pragma mark - PHPhotoLibraryChangeObserver

- (void)photoLibraryDidChange:(PHChange *)changeInfo
{
    [self loadAssert];
}

#pragma mark -- Notification

- (void)userDidTakeScreenshot:(NSNotification *)notification
{
    __weak typeof(self) weakSelf = self;
    [self.assertModel assertForType:_type assertsGroup:self.assertGroup block:^(NSMutableArray *currentGroupAssertsArray) {
        dispatch_async(dispatch_get_main_queue(), ^{
             weakSelf.assertModel.currentGroupAsserts = currentGroupAssertsArray;
             [weakSelf.collectionView reloadData];
        });
    }];
}

@end


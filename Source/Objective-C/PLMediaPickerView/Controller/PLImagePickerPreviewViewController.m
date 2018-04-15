//
//  PLImagePickerPreviewViewController.m
//  QiuBai
//
//  Created by 小飞 刘 on 11/3/15.
//  Copyright © 2015 Less Everything. All rights reserved.
//

#import "PLImagePickerPreviewViewController.h"
#import "PLImagePickerPreviewCell.h"
#import "UIButton+PLEnLargeEdge.h"
#import <POP.h>
#import "PLAssertManager.h"
#import "PLUIHelper.h"
#import "Constant.h"
#import "UIDevice+PLPL.h"
#import "PLUIViewAdditions.h"

#define BottomBarHeight 45

@interface PLImagePickerPreviewViewController () <UIScrollViewDelegate>

@property (strong,nonatomic) UIButton *bottomBarRightBtn;
@property (strong,nonatomic) UILabel *bottomBarSelectedLabel;
@property (strong,nonatomic) UIView *bottomToolBarView;
@property (strong,nonatomic) ALAsset *currentAsset;
@property (nonatomic) CGSize cellSize;
@property (nonatomic) CGFloat cellSpacing;
@property (nonatomic) CGFloat selectionSpacing;
@property (nonatomic,strong) UIButton *navLeftBtn;
@property (nonatomic,strong) UIButton *rightBarBtn;

@end

@implementation PLImagePickerPreviewViewController

static NSString * const reuseIdentifier = @"Cell";

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self setNavigationBar];
    [self setBottomToolBar];
    if (!self.doneBtnName) {
        self.doneBtnName = @"完成";
    }
    if (!self.selectedAsserts) {
        self.selectedAsserts = [[NSMutableArray alloc] init];
    }
    self.cellSpacing = 0;
    self.selectionSpacing = 0;
    NSInteger cellNumberInSingleLine = 1;
    CGFloat cellWidth = (self.view.frame.size.width - self.cellSpacing * 3 - self.selectionSpacing * 2) / cellNumberInSingleLine;
    self.cellSize = CGSizeMake(cellWidth, cellWidth);
    self.collectionView.showsHorizontalScrollIndicator = NO;
    self.collectionView.showsVerticalScrollIndicator = NO;
    self.collectionView.pagingEnabled = YES;
    if ([[UIDevice new] isPLIOS10AndAbove]) {
        self.collectionView.prefetchingEnabled = NO;
    }
    [self.collectionView registerClass:[PLImagePickerPreviewCell class] forCellWithReuseIdentifier:@"identifier"];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(plImagePickerPreViewCellDidSingleTap) name:@"PLImagePickerPreViewCellDidSingleTap" object:nil];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    if (self.jumpIndexPath && [self.collectionView numberOfItemsInSection:0] > self.jumpIndexPath.item) {
        // 有个闪退，https://bugly.qq.com/v2/crash-reporting/crashes/900010871/3258397?pid=2
        [self.collectionView scrollToItemAtIndexPath:self.jumpIndexPath atScrollPosition:UICollectionViewScrollPositionNone animated:NO];
    }
}

#pragma mark -- Private Method
- (void)setNavigationBar
{
    self.navigationController.navigationBar.barTintColor = UIColorFromRGB(VideoSelectNavBackground);
    self.navigationController.navigationBar.tintColor = [UIColor whiteColor];
    [self.navigationController.navigationBar setTitleTextAttributes:@{NSForegroundColorAttributeName : UIColorFromRGB(VideoSelectNavTitle)}];
    
    self.rightBarBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.rightBarBtn setImage:[UIImage imageNamed:@"resource.bundle/photo_localUnselected_tag@3x.png"] forState:UIControlStateNormal];
    [self.rightBarBtn setImage:[UIImage imageNamed:@"resource.bundle/photo_localSelected_tag@3x.png"] forState:UIControlStateSelected];
    [self.rightBarBtn setTitleColor:UIColorFromRGB(VideoSelectNavTextBackground) forState:UIControlStateNormal];
    [self.rightBarBtn sizeToFit];
    [self.rightBarBtn addTarget:self action:@selector(rightBarBtnPressed) forControlEvents:UIControlEventTouchUpInside];
    [self.rightBarBtn setEnlargeEdgeWithTop:10 right:15 bottom:10 left:15];
    UIBarButtonItem *rightBarItem = [[UIBarButtonItem alloc] initWithCustomView:self.rightBarBtn];
    self.navigationItem.rightBarButtonItem = rightBarItem;
    
    UIButton *btn = [self setLeftBarItem:@"resource.bundle/icon_back@3x.png" accessibilityHint:@"点两下返回" accesssibilityLabel:@"返回"];
    [btn setEnlargeEdgeWithTop:10 right:25 bottom:10 left:15];
    [btn addTarget:self action:@selector(popVCwithAnimation) forControlEvents:UIControlEventTouchUpInside];
}

- (UIButton *)setLeftBarItem:(NSString *)imageName accessibilityHint:(NSString *)hint accesssibilityLabel:(NSString *)label
{
    UIImage *image = [UIImage imageNamed:imageName];
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    [button setImage:image forState:UIControlStateNormal];
    [button setShowsTouchWhenHighlighted:NO];
    [button setAdjustsImageWhenHighlighted:NO];
    button.frame= CGRectMake(0.0, 0.0, 48, image.size.height);
    button.imageEdgeInsets = UIEdgeInsetsMake(0, -42, 0, 0);
    UIBarButtonItem *forward = [[UIBarButtonItem alloc] initWithCustomView:button];
    forward.accessibilityHint = hint;
    forward.accessibilityLabel = label;
    self.navigationItem.leftBarButtonItem= forward;
    self.navLeftBtn = button;
    return button;
}

- (void)popVCwithAnimation
{
    [self.pickerVC.collectionView reloadData];
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)setBottomToolBar
{
    self.bottomToolBarView = [[UIView alloc] initWithFrame:CGRectMake(0, self.view.frame.size.height - (BottomBarHeight + safeAreaBottomPadding), [UIScreen mainScreen].bounds.size.width, BottomBarHeight + safeAreaBottomPadding)];
    self.bottomToolBarView.backgroundColor = [UIColor blackColor];
    self.bottomToolBarView.alpha = 0.8;
    [self.view addSubview:self.bottomToolBarView];
    
    if (!PLPLMyDevice().isPLIOS9AndAbove) {
        self.bottomToolBarView.bottom += 20;
    }
    
    self.bottomBarRightBtn = [[UIButton alloc] initWithFrame:CGRectMake(self.bottomToolBarView.frame.size.width - 100, 0, 100, self.bottomToolBarView.frame.size.height - safeAreaBottomPadding)];
    [self.bottomBarRightBtn setTitleColor:UIColorFromRGB(VideoSelectNavTextBackground) forState:UIControlStateNormal];
    
    self.bottomBarRightBtn.titleLabel.font = [PLUIHelper fontWithSize:15.0f];
    self.bottomBarRightBtn.contentEdgeInsets = UIEdgeInsetsMake(0, 25, 0, 0);
    self.bottomBarRightBtn.titleLabel.textAlignment = NSTextAlignmentCenter;
    [self.bottomBarRightBtn addTarget:self action:@selector(bottomBarRightBtnPressed) forControlEvents:UIControlEventTouchUpInside];
    [self.bottomBarRightBtn setTitle:self.doneBtnName forState:UIControlStateNormal];
    [self.bottomToolBarView addSubview:self.bottomBarRightBtn];
    
    self.bottomBarSelectedLabel = [[UILabel alloc] initWithFrame:CGRectMake(self.bottomToolBarView.frame.size.width - 78, self.bottomToolBarView.frame.size.height / 2 - 20 / 2 - safeAreaBottomPadding / 2, 20, 20)];
    self.bottomBarSelectedLabel.textColor = [UIColor whiteColor];
    self.bottomBarSelectedLabel.backgroundColor = UIColorFromRGB(0xffa015);
    self.bottomBarSelectedLabel.font = [PLUIHelper fontWithSize:13.0f];
    self.bottomBarSelectedLabel.clipsToBounds = YES;
    self.bottomBarSelectedLabel.layer.cornerRadius = self.bottomBarSelectedLabel.frame.size.width / 2;
    self.bottomBarSelectedLabel.text = [NSString stringWithFormat:@"%ld",(long)self.selectedAsserts.count];
    self.bottomBarSelectedLabel.textAlignment = NSTextAlignmentCenter;
    [self.bottomToolBarView addSubview:self.bottomBarSelectedLabel];
    
    if (self.selectedAsserts.count > 0) {
        self.bottomBarSelectedLabel.hidden = NO;
    } else {
        self.bottomBarSelectedLabel.hidden = YES;
    }
}

- (void)returnErrorMsg:(NSString *)msg
{
    NSDictionary *userInfo = [NSDictionary dictionaryWithObject:msg                                                                      forKey:NSLocalizedDescriptionKey];
    NSError *error = [[NSError alloc] initWithDomain:msg code:-1 userInfo:userInfo];
    if ([self.delegate respondsToSelector:@selector(error)]) {
        [self.delegate error:error];
    }
}

- (void)rightBarBtnPressed
{
    if (self.selectedAsserts.count >= self.maxNumberOfPhotos && ![self.rightBarBtn isSelected]) {
        NSString *tip = [NSString stringWithFormat:@"最多只能选取%ld张图片哦",(long)self.maxNumberOfPhotos];
        [self returnErrorMsg:tip];
        return;
    }
    
    if ([self.rightBarBtn isSelected]) {
        [self.rightBarBtn setSelected:NO];
        
        ALAsset *assetNeedRemove;
        for (ALAsset *selectAsset in self.selectedAsserts) {
            if ([PLAssertManager isEqulAssert:selectAsset nextAssert:self.currentAsset]) {
                assetNeedRemove = selectAsset;
            }
        }
        if (assetNeedRemove) {
            [self.selectedAsserts removeObject:assetNeedRemove];
        }
    } else {
        [self.rightBarBtn setSelected:YES];
        [self.selectedAsserts addObject:self.currentAsset];
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

- (void)bottomBarRightBtnPressed
{
    if (!self.selectedAsserts || self.selectedAsserts.count == 0) {
        // 没有选择图片自动添加当前预览图片
        [self.selectedAsserts addObject:self.currentAsset];
    }
    
    if ([_delegate respondsToSelector:@selector(mediaInfo:)]) {
        [_delegate mediaInfo:self.selectedAsserts];
        
        if (self.dismissWhenComplete) {
            [self dismissViewControllerAnimated:YES completion:nil];
        }
    }
}

- (void)plImagePickerPreViewCellDidSingleTap
{
    if (self.bottomToolBarView.isHidden) {
        self.bottomToolBarView.hidden = NO;
        self.navigationController.navigationBar.alpha = 1.0;
        [UIApplication sharedApplication].statusBarStyle = UIStatusBarStyleDefault;
        self.navigationController.interactivePopGestureRecognizer.enabled = YES;
        
    } else {
        self.bottomToolBarView.hidden = YES;
        self.navigationController.navigationBar.alpha = 0.0;
        [UIApplication sharedApplication].statusBarStyle = UIStatusBarStyleLightContent;
        self.navigationController.interactivePopGestureRecognizer.enabled = NO;
    }
}

#pragma mark <UICollectionViewDataSource>

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    return self.asserts.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    PLImagePickerPreviewCell *cell = (PLImagePickerPreviewCell*)[collectionView dequeueReusableCellWithReuseIdentifier:@"identifier" forIndexPath:indexPath];
    [cell bindData:self.asserts[indexPath.row]];
    
    [self setRightBarBtnWithIndex:indexPath.row];
    return cell;
}

#pragma mark <UICollectionViewDelegate>

- (CGFloat)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout minimumLineSpacingForSectionAtIndex:(NSInteger)section
{
    return 0;
}
- (CGFloat)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout minimumInteritemSpacingForSectionAtIndex:(NSInteger)section
{
    return 0;
}

-(UIEdgeInsets)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout insetForSectionAtIndex:(NSInteger)section
{
    return UIEdgeInsetsMake(-64,0,0,0);
}

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath
{
    return CGSizeMake(self.collectionView.frame.size.width, self.collectionView.frame.size.height);
}

-(BOOL)collectionView:(UICollectionView *)collectionView shouldSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    return YES;
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView
{
    NSInteger index = (NSInteger )scrollView.contentOffset.x / [UIScreen mainScreen].bounds.size.width;
    [self setRightBarBtnWithIndex:index];
}

//设置右上角按钮状态
- (void)setRightBarBtnWithIndex:(NSInteger)index
{
    self.currentAsset = self.asserts[index];
    BOOL isAssetExist = NO;
    for (ALAsset *asset in self.selectedAsserts) {
        if (asset.hash == self.currentAsset.hash) {
            isAssetExist = YES;
        }
    }
    if (isAssetExist) {
        [self.rightBarBtn setSelected:YES];
    } else {
        [self.rightBarBtn setSelected:NO];
    }
}

@end


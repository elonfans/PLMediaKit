//
//  PLImagePickerGroupController.m
//  QiuBai
//
//  Created by 小飞 刘 on 9/17/15.
//  Copyright © 2015 Less Everything. All rights reserved.
//

#import "PLImagePickerGroupController.h"
#import <AssetsLibrary/AssetsLibrary.h>
#import "PLImagePickerController.h"
#import "PLAssertManager.h"
#import <Photos/Photos.h>
#import "PLAssertGroupModel.h"
#import "Constant.h"
#import "PLUIHelper.h"

@interface PLImagePickerGroupController ()<UITableViewDelegate,UITableViewDataSource>

@property(nonatomic,strong) UITableView *tableView;
@property (nonatomic, strong) ALAssetsLibrary *assetsLibrary;
@property (nonatomic, strong) PLAssertManager *assertModel;

@end

@implementation PLImagePickerGroupController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    if (self.type == PickerTypeImage) {
        self.title = @"本地照片";
    } else if (self.type == PickerTypeVideo) {
        self.title = @"本地视频";
    }
    
    self.navigationController.navigationBar.barTintColor = UIColorFromRGB(VideoSelectNavBackground);
    self.navigationController.navigationBar.tintColor = [UIColor whiteColor];
    [self.navigationController.navigationBar setTitleTextAttributes:@{NSForegroundColorAttributeName : UIColorFromRGB(VideoSelectNavTitle)}];
    self.view.backgroundColor = UIColorFromRGB(VideoSelectBackground);

    [self setNavigationBar];
    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds
                                                  style:UITableViewStylePlain];
    self.tableView.backgroundColor = UIColorFromRGB(VideoSelectBackground);
    self.tableView.separatorColor = UIColorFromRGB(VideoSelectTableViewCellSparate);
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.tableFooterView = [[UIView alloc] init];
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:self.tableView];
    self.tableView.contentInset = UIEdgeInsetsMake(0, -15, 0, 0);
    self.tableView.separatorInset = UIEdgeInsetsMake(0, 0, 0, -15);
    
    self.assertModel = [PLAssertManager new];
    
    __weak typeof(self) weakSelf = self;
//    [self.assertModel assertGroupsBlock:^(NSArray *PLAssertGroupModelArray) {
//        weakSelf.assertModel.assertGroups = PLAssertGroupModelArray;
//        [weakSelf.tableView performSelectorOnMainThread:@selector(reloadData) withObject:nil waitUntilDone:NO];
//    }];
//    
    [self.assertModel assertGroupsForType:_type block:^(NSArray *PLAssertGroupModelArray) {
        weakSelf.assertModel.assertGroups = PLAssertGroupModelArray;
        [weakSelf.tableView performSelectorOnMainThread:@selector(reloadData) withObject:nil waitUntilDone:NO];
    }];
}

- (void)viewSafeAreaInsetsDidChange
{
    [super viewSafeAreaInsetsDidChange];
    if (@available(iOS 11, *)) {
        self.tableView.frame = CGRectMake(self.view.safeAreaInsets.left,
                                          self.view.safeAreaInsets.top,
                                          CGRectGetWidth(self.view.frame) - self.view.safeAreaInsets.left - self.view.safeAreaInsets.right,
                                          CGRectGetHeight(self.view.frame) - self.view.safeAreaInsets.top - self.view.safeAreaInsets.bottom);
    }
}

#pragma mark - private

- (void)setNavigationBar
{
    // cancel btn
    UIButton *rightBarBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    rightBarBtn.titleLabel.font = [PLUIHelper fontWithSize:17.0f];
    [rightBarBtn setTitle:@"取消" forState:UIControlStateNormal];
    [rightBarBtn setTitleColor:UIColorFromRGB(VideoSelectNavTextBackground) forState:UIControlStateNormal];
    [rightBarBtn sizeToFit];
    [rightBarBtn addTarget:self action:@selector(rightBarBtnPressed) forControlEvents:UIControlEventTouchUpInside];
    UIBarButtonItem *rightBarBtnItem = [[UIBarButtonItem alloc] initWithCustomView:rightBarBtn];
    self.navigationItem.rightBarButtonItem = rightBarBtnItem;
}

- (void)rightBarBtnPressed
{
    [self.navigationController dismissViewControllerAnimated:YES completion:nil];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static  NSString *indextifier = @"cell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:indextifier];
    
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:indextifier];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.textLabel.textColor = [UIColor whiteColor];
        cell.imageView.contentMode = PHImageContentModeAspectFill;
        cell.backgroundColor = UIColorFromRGB(VideoSelectBackground);
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    }
    PLAssertGroupModel *assertGroupModel = [self.assertModel.assertGroups objectAtIndex:indexPath.row];
    cell.textLabel.text = assertGroupModel.title;
    cell.detailTextLabel.text = [assertGroupModel.count stringValue];
    [PLAssertManager assertImage:assertGroupModel.collection size:CGSizeMake(120, 120) usingBlock:^(UIImage *image, BOOL isGif) {
        dispatch_async(dispatch_get_main_queue(), ^{
            cell.imageView.image = image;
        });
    } isNeedCompressed:NO];
    
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 66;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:NO];
    
    PLAssertGroupModel *assertGroupModel = [self.assertModel.assertGroups objectAtIndex:indexPath.row];
    PLImagePickerController *vc = [PLImagePickerController imagePickerController];
    if (vc) {
        vc.maxNumberOfPhotos = self.maxNumberOfPhotos;
        vc.delegate = self.delegate;
        vc.title = assertGroupModel.title;
        vc.assertGroup = assertGroupModel.collection;
        vc.supportPreview = self.supportPreview;
        vc.supportTakePhoto = self.supportTakePhoto;
        vc.dismissWhenComplete = self.dismissWhenComplete;
        vc.type = self.type;
        [self.navigationController pushViewController:vc animated:YES];
    }
}

#pragma mark - table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.assertModel.assertGroups.count;
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

@end

//
//  ViewController.m
//  Demo
//
//  Created by Pauley Liu on 29/08/2017.
//  Copyright © 2017 Pauley Liu. All rights reserved.
//

#import "ViewController.h"
//#import "PLMediaPickerViewController.h"
#import "PLMediaKit.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    UIButton *pickerBtn1 = [UIButton buttonWithType:UIButtonTypeCustom];
    [pickerBtn1 setTitle:@"从相册选择（图）" forState:UIControlStateNormal];
    [pickerBtn1 setTitleColor:[UIColor blueColor] forState:UIControlStateNormal];
    pickerBtn1.frame = CGRectMake(self.view.frame.size.width / 2 - 150, 200, 300, 20);
    [pickerBtn1 addTarget:self action:@selector(onClickPickerBtn1:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:pickerBtn1];
    
    UIButton *pickerBtn2 = [UIButton buttonWithType:UIButtonTypeCustom];
    [pickerBtn2 setTitle:@"从相册选择（视频）" forState:UIControlStateNormal];
    [pickerBtn2 setTitleColor:[UIColor blueColor] forState:UIControlStateNormal];
    pickerBtn2.frame = CGRectMake(self.view.frame.size.width / 2 - 150, 300, 300, 20);
    [pickerBtn2 addTarget:self action:@selector(onClickPickerBtn2:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:pickerBtn2];
}

- (void)onClickPickerBtn1:(id)sender
{
    // 从相册选择（图）
    PLMediaPickerViewController *vc = [[PLMediaPickerViewController alloc] init];
    vc.dismissWhenComplete = YES;
    vc.maxNumber = 6;
    vc.type = PickerTypeImage;
    [vc callBackImagesData:^(NSArray *imagesData) {
        NSLog(@"%@", imagesData);
    } error:^(NSError *error) {
        NSLog(@"%@", error.localizedDescription);
    }];
    [self presentViewController:vc animated:YES completion:nil];
}

- (void)onClickPickerBtn2:(id)sender
{
    // 从相册选择（视频）
    PLMediaPickerViewController *vc = [[PLMediaPickerViewController alloc] init];
    vc.dismissWhenComplete = YES;
    vc.maxNumber = 1;
    vc.type = PickerTypeVideo;
    [vc callBackVideoModel:^(PLVideoModel *model) {
        NSLog(@"%@ %@ %@", model.path, model.videoOriginHash, model.image);
    } error:^(NSError *error) {
        NSLog(@"%@", error);
    }];
    [self presentViewController:vc animated:YES completion:nil];
}

@end

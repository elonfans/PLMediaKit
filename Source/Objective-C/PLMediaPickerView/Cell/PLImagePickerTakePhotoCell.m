//
//  PLImagePickerTakePhotoCell.m
//  QiuBai
//
//  Created by 小飞 刘 on 9/18/15.
//  Copyright © 2015 Less Everything. All rights reserved.
//

#import "PLImagePickerTakePhotoCell.h"
#import "Constant.h"

@interface PLImagePickerTakePhotoCell()

@property (nonatomic,strong) UIImageView *takePhotoImageView;

@end

@implementation PLImagePickerTakePhotoCell

- (void)layoutSubviews
{
    self.backgroundColor = UIColorFromRGB(0x444444);

    // takePhotoImageView
    if (!self.takePhotoImageView) {
        CGFloat width = 0;
        CGFloat height = 0;
        UIImage *image;
        if (self.pickerType == PickerTypeImage) {
            width = 23;
            height = 23;
            image = [UIImage imageNamed:@"resource.bundle/photo_localSelected_camera@3x.png"];
        } else if (self.pickerType == PickerTypeVideo) {
            width = 30;
            height = 30;
            image = [UIImage imageNamed:@"resource.bundle/photo_localSelected_video@3x.png"];
        }
        
        self.takePhotoImageView = [[UIImageView alloc] initWithFrame:CGRectMake(self.contentView.frame.size.width / 2 - width / 2, self.contentView.frame.size.height / 2 - height / 2, width, height)];
        self.takePhotoImageView.image = image;
        [self.contentView addSubview:self.takePhotoImageView];
    }
}

@end

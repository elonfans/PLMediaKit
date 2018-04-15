//
//  PLImagePickerCell.m
//  QiuBai
//
//  Created by 小飞 刘 on 9/17/15.
//  Copyright © 2015 Less Everything. All rights reserved.
//

#import "PLImagePickerCell.h"
#import "UIButton+PLEnLargeEdge.h"
#import <Photos/Photos.h>
#import "PLAssertManager.h"
#import "UIImage+PLExtends.h"
#import "PLVideoRecorderHelper.h"
#import "PLUIHelper.h"

@interface PLImagePickerCell ()

@property (nonatomic, strong) UIImageView *thumbNailImageView;
@property (nonatomic, strong) UIImageView *gifTagImageView;
@property (nonatomic, strong) UIImageView *videoMaskView;
@property (nonatomic, strong) UILabel *videoTimeLabel;
@property (nonatomic, strong) UIActivityIndicatorView *indicatorView;

@end

@implementation PLImagePickerCell

- (void)bindData:(PHAsset *)asset supportPreview:(BOOL)supportPreview
{
    self.currentAsset = asset;
    
    // thumNail
    if (!self.thumbNailImageView) {
        self.thumbNailImageView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, self.frame.size.width, self.frame.size.height)];
        self.thumbNailImageView.contentMode = UIViewContentModeScaleAspectFill;
        self.thumbNailImageView.clipsToBounds = YES;
        [self.contentView addSubview:self.thumbNailImageView];
    }
    
    // gifTag
    if (!self.gifTagImageView) {
        self.gifTagImageView = [[UIImageView alloc] initWithFrame:CGRectMake(self.frame.size.width - 26 - 5, self.frame.size.height - 15 - 5, 26, 15)];
        self.gifTagImageView.contentMode = UIViewContentModeScaleAspectFill;
        self.gifTagImageView.clipsToBounds = YES;
        self.gifTagImageView.image = [UIImage imageNamed:@"resource.bundle/gif_tag@3x.png"];
        [self.contentView addSubview:self.gifTagImageView];
        self.gifTagImageView.hidden = YES;
    }
    
    // selectedTagBtn
    if (supportPreview) {
        if (!self.selectedTagBtn) {
            self.selectedTagBtn = [UIButton buttonWithType:UIButtonTypeCustom];
            self.selectedTagBtn.frame = CGRectMake(self.frame.size.width - 15 - 5, 5, 18, 18);
            [self.selectedTagBtn setEnlargeEdgeWithTop:5 right:5 bottom:20 left:20];
            [self.selectedTagBtn setImage:[UIImage imageNamed:@"resource.bundle/photo_localUnselected_tag@3x.png"] forState:UIControlStateNormal];
            [self.selectedTagBtn setImage:[UIImage imageNamed:@"resource.bundle/photo_localSelected_tag@3x.png"] forState:UIControlStateSelected];
            [self.selectedTagBtn setSelected:NO];
            [self.selectedTagBtn addTarget:self action:@selector(selectedTagBtnPressed) forControlEvents:UIControlEventTouchUpInside];
            [self.contentView addSubview:self.selectedTagBtn];
        }
    }

    // videoMaskView
    if (!self.videoMaskView) {
        self.videoMaskView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, self.frame.size.width, self.frame.size.height)];
        self.videoMaskView.image = [UIImage imageNamed:@"resource.bundle/video_localSelected_mask@3x.png"];
        [self addSubview:self.videoMaskView];
        self.videoMaskView.hidden = YES;
    }
    
    // videoTimeLabel
    if (!self.videoTimeLabel) {
        self.videoTimeLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, self.frame.size.height - 15, self.frame.size.width, 15)];
        self.videoTimeLabel.textAlignment = NSTextAlignmentCenter;
        self.videoTimeLabel.textColor = [UIColor whiteColor];
        self.videoTimeLabel.font = [PLUIHelper fontWithSize:10.0f];
        [self.videoMaskView addSubview:self.videoTimeLabel];
        self.videoTimeLabel.hidden = YES;
    }

    // indicatorView
    if (!_indicatorView) {
        self.indicatorView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
        self.indicatorView.hidesWhenStopped = YES;
        self.indicatorView.center = CGPointMake(self.frame.size.width / 2, self.frame.size.height / 2);
        [self addSubview:self.indicatorView];
    }

    if (asset.mediaType == PHAssetResourceTypeVideo) {
        self.videoTimeLabel.text = [[self class] convertTime:round(self.currentAsset.duration)];
        self.videoMaskView.hidden = NO;
        self.videoTimeLabel.hidden = NO;
        self.selectedTagBtn.hidden = YES;
    } else {
        self.videoMaskView.hidden = YES;
        self.videoTimeLabel.hidden = YES;
    }

    CGFloat memoryFactor = [[self class] getMemoryFactor];
    __weak __typeof(self)weakSelf = self;
    [PLAssertManager assertImage:asset size:CGSizeMake(self.frame.size.width * memoryFactor, self.frame.size.height * memoryFactor) usingBlock:^(UIImage *image, BOOL isGif) {
        dispatch_async(dispatch_get_main_queue(), ^{
            weakSelf.thumbNailImageView.image = image;
            // gifTag
            if (isGif) {
                weakSelf.gifTagImageView.hidden = NO;
            } else {
                weakSelf.gifTagImageView.hidden = YES;
            }
        });
    } isNeedCompressed:NO];
}

// 内存系数，内存越大获取预览图越清晰
+ (CGFloat)getMemoryFactor
{
    NSInteger memorySize = [NSProcessInfo processInfo].physicalMemory / 1024 / 1024;
    NSInteger memory = memorySize / 900;
    if (memory >= 3) {
        return 1;
    } else if (memory == 2) {
        return 0.75;
    } else {
        return 0.66;
    }
}

- (void)startLoading
{
    [self.indicatorView startAnimating];
}

- (void)stopLoading
{
    [self.indicatorView stopAnimating];
}

// 时间格式转换
+ (NSString *)convertTime:(CGFloat)second
{
    NSDate *d = [NSDate dateWithTimeIntervalSince1970:second];
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    if (second / 3600 >= 1) {
        [formatter setDateFormat:@"HH:mm:ss"];
    } else {
        [formatter setDateFormat:@"mm:ss"];
    }
    NSString *showtimeNew = [formatter stringFromDate:d];
    return showtimeNew;
}

- (void)selectedTagBtnPressed
{
    if ([_delegate respondsToSelector:@selector(selectedAsset:cell:)]) {
        [_delegate selectedAsset:self.currentAsset cell:self];
    }
}

@end

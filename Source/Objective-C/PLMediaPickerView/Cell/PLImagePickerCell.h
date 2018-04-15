//
//  PLImagePickerCell.h
//  QiuBai
//
//  Created by 小飞 刘 on 9/17/15.
//  Copyright © 2015 Less Everything. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AssetsLibrary/AssetsLibrary.h>
#import <Photos/Photos.h>

@class PLImagePickerCell;

@protocol PLImagePickerCellDelegate <NSObject>

- (void)selectedAsset:(PHAsset *)asset cell:(PLImagePickerCell *)cell;

@end

@interface PLImagePickerCell : UICollectionViewCell

@property (nonatomic, strong) UIButton *selectedTagBtn;
@property (nonatomic, weak) id<PLImagePickerCellDelegate> delegate;
@property (nonatomic, strong) PHAsset *currentAsset;

- (void)bindData:(PHAsset *)asset supportPreview:(BOOL)supportPreview;
- (void)startLoading;
- (void)stopLoading;

@end

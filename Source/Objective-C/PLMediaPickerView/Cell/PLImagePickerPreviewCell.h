//
//  PLImagePickerPreviewCell.h
//  QiuBai
//
//  Created by 小飞 刘 on 11/3/15.
//  Copyright © 2015 Less Everything. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AssetsLibrary/AssetsLibrary.h>

@interface PLImagePickerPreviewCell : UICollectionViewCell

@property (nonatomic) BOOL isSelected;
- (void)bindData:(ALAsset*)asset;

@end

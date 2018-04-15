//
//  PLImagePickerPreviewCell.m
//  QiuBai
//
//  Created by 小飞 刘 on 11/3/15.
//  Copyright © 2015 Less Everything. All rights reserved.
//

#import "PLImagePickerPreviewCell.h"
#import "UIImage+PLExtends.h"
#import "PLAssertManager.h"
#import "UIImage+animatedGIF.h"
#import "FLAnimatedImageView.h"
#import "FLAnimatedImage.h"

#define UISCREEN_WIDTH      [UIScreen mainScreen].bounds.size.width
#define UISCREEN_HEIGHT     [UIScreen mainScreen].bounds.size.height

static const CGFloat kMaxImageScale = 2.5f;
static const CGFloat kMinImageScale = 1.0f;

@interface PLImagePickerPreviewCell () <UIScrollViewDelegate>

@property (nonatomic, strong) FLAnimatedImageView *thumbNailImageView;
@property (nonatomic, strong) UIScrollView *scrollView;

@end

@implementation PLImagePickerPreviewCell

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.scrollView = [[UIScrollView alloc] initWithFrame:self.bounds];
        self.scrollView.delegate = self;
        self.scrollView.backgroundColor = [UIColor clearColor];
        [self.contentView addSubview:self.scrollView];
        
        self.scrollView.minimumZoomScale = kMinImageScale;
        self.scrollView.maximumZoomScale = kMaxImageScale;
        
        self.thumbNailImageView = [[FLAnimatedImageView alloc] initWithFrame:self.scrollView.bounds];
        self.thumbNailImageView.contentMode = UIViewContentModeScaleAspectFill;
        self.thumbNailImageView.clipsToBounds = YES;
        [self.scrollView addSubview:self.thumbNailImageView];
        
        [self addMutipleGesture];
    }
    return self;
}

#pragma mark- bind data

- (void)bindData:(ALAsset *)asset
{
    self.thumbNailImageView.image = nil;
    __weak typeof(self) weakSelf = self;
    [PLAssertManager assertImage:asset size:CGSizeMake(self.frame.size.width, self.frame.size.height) usingDataBlock:^(NSData *imageData, BOOL isGif) {
        dispatch_async(dispatch_get_main_queue(), ^{
            CGSize imageSize;
            if (isGif) {
                FLAnimatedImage *image = [[FLAnimatedImage alloc] initWithAnimatedGIFData:imageData];
                weakSelf.thumbNailImageView.animatedImage = image;
                imageSize = image.posterImage.size;
            } else {
                UIImage *image = [UIImage imageWithData:imageData];
                weakSelf.thumbNailImageView.image = image;
                imageSize = image.size;
            }
            CGFloat contentSizeHeight = UISCREEN_WIDTH * imageSize.height / imageSize.width;
            if (contentSizeHeight > UISCREEN_HEIGHT) {
                weakSelf.scrollView.contentSize = CGSizeMake(UISCREEN_WIDTH, contentSizeHeight);
                weakSelf.thumbNailImageView.frame = CGRectMake(0, 0, UISCREEN_WIDTH, contentSizeHeight);
            } else {
                weakSelf.scrollView.contentSize = weakSelf.scrollView.bounds.size;
                weakSelf.thumbNailImageView.frame = weakSelf.scrollView.bounds;
            }
        });
    } isNeedCompressed:NO];
    self.thumbNailImageView.contentMode = UIViewContentModeScaleAspectFit;
}

#pragma mark - gestures

- (void)addMutipleGesture
{
    UITapGestureRecognizer *doubleTapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(didDoubleTap:)];
    doubleTapRecognizer.numberOfTapsRequired = 2;
    doubleTapRecognizer.numberOfTouchesRequired = 1;
    [self.scrollView addGestureRecognizer:doubleTapRecognizer];
    
    UITapGestureRecognizer *singleTapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(didSingleTap:)];
    singleTapRecognizer.numberOfTapsRequired = 1;
    singleTapRecognizer.numberOfTouchesRequired = 1;
    [self.scrollView addGestureRecognizer:singleTapRecognizer];
    
    [singleTapRecognizer requireGestureRecognizerToFail:doubleTapRecognizer];
}

- (void)didDoubleTap:(UITapGestureRecognizer *)recognizer
{
    CGPoint pointInView = [recognizer locationInView:self];
    [self zoomInZoomOut:pointInView];
}

- (void)didSingleTap:(UITapGestureRecognizer *)recognizer
{
    [[NSNotificationCenter defaultCenter] postNotificationName:@"PLImagePickerPreViewCellDidSingleTap" object:nil];
}

#pragma mark - scrollview delegate

- (UIView *)viewForZoomingInScrollView:(UIScrollView *)scrollView
{
    return self.thumbNailImageView;
}

- (void)scrollViewDidZoom:(UIScrollView *)scrollView
{
    CGRect frame = self.thumbNailImageView.frame;
    frame.origin.y = (self.scrollView.frame.size.height - self.thumbNailImageView.frame.size.height) > 0 ? (self.scrollView.frame.size.height - self.thumbNailImageView.frame.size.height) * 0.5 : 0;
    frame.origin.x = (self.scrollView.frame.size.width - self.thumbNailImageView.frame.size.width) > 0 ? (self.scrollView.frame.size.width - self.thumbNailImageView.frame.size.width) * 0.5 : 0;
    self.thumbNailImageView.frame = frame;
}

#pragma mark - method

- (void)zoomInZoomOut:(CGPoint)point
{
    CGFloat newZoomScale = self.scrollView.zoomScale >= kMaxImageScale ? kMinImageScale : kMaxImageScale;
    
    CGSize scrollViewSize = self.scrollView.bounds.size;
    CGFloat w = scrollViewSize.width / newZoomScale;
    CGFloat h = scrollViewSize.height / newZoomScale;
    CGFloat x = point.x - (w / 2.0f);
    CGFloat y = point.y - (h / 2.0f);
    CGRect rectToZoomTo = CGRectMake(x, y, w, h);
    [self.scrollView zoomToRect:rectToZoomTo animated:YES];
}

@end

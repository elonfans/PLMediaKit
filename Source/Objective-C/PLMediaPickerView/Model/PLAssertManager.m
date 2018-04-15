//
//  PLAssertManager.m
//  QiuBai
//
//  Created by 小飞 刘 on 5/24/16.
//  Copyright © 2016 Less Everything. All rights reserved.
//

#import "PLAssertManager.h"
#import "PLAssertGroupModel.h"
#import <Photos/Photos.h>
#import <MBProgressHUD.h>
#import "UIDevice+PLPL.h"
#import "UIImage+PLExtends.h"

@implementation PLAssertManager

/**
 *  获取当前 Assert Group 的全部 Assert 资源
 *
 *  @param assertsGroup 资源组
 *  @param block        回调当前组包含的全部Assert资源
 */
- (void)assertForType:(PickerType)type assertsGroup:(id)assertsGroup block:(void (^)(NSMutableArray *currentGroupAssertsArray))block
{
    if (!assertsGroup) {
        [self currentGroupAssertsForType:type block:^(NSMutableArray *currentGroupAssertsArray) {
            block(currentGroupAssertsArray);
        }];
        return;
    }
    NSMutableArray *currentGroupAssertsArray = [NSMutableArray new];
    for (PHAsset *asset in assertsGroup) {
        if (type == PickerTypeImage) {
            if (asset.mediaType == PHAssetMediaTypeImage) {
                [currentGroupAssertsArray insertObject:asset atIndex:0];
            }
        }
        if (type == PickerTypeVideo) {
            if (asset.mediaType == PHAssetMediaTypeVideo) {
                [currentGroupAssertsArray insertObject:asset atIndex:0];
            }
        }
    }
    block(currentGroupAssertsArray);
}

/**
 *  获取全部assert资源（默认组）
 *
 *  @param block 回调全部assert资源
 */
- (void)currentGroupAssertsForType:(PickerType)type block:(void (^)(NSMutableArray *currentGroupAssertsArray))block
{
    NSMutableArray *currentGroupAssertsArray = [NSMutableArray new];
    PHFetchOptions *allPhotosOptions = [[PHFetchOptions alloc] init];
    allPhotosOptions.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"creationDate" ascending:YES]];
    
    PHFetchResult *results = [PHAsset fetchAssetsWithOptions:allPhotosOptions];
    for (PHAsset *asset in results) {
        if (asset.mediaType == PHAssetMediaTypeImage && (type == PickerTypeImage)) {
            [currentGroupAssertsArray insertObject:asset atIndex:0];
        }
        if (asset.mediaType == PHAssetMediaTypeVideo && (type == PickerTypeVideo)) {
            [currentGroupAssertsArray insertObject:asset atIndex:0];
        }
    }
    block(currentGroupAssertsArray);
}

/**
 *  获取全部Assert Groups(已过滤资源数量为0的group)
 *
 *  @param block 回调全部Assert Groups
 */
- (void)assertGroupsForType:(PickerType)type block:(void (^)(NSArray *PLAssertGroupModelArray))block
{
    NSMutableArray *PLAssertGroupModelArray = [NSMutableArray new];
    
    PHFetchResult *smartAlbums = [PHAssetCollection fetchAssetCollectionsWithType:PHAssetCollectionTypeSmartAlbum subtype:PHAssetCollectionSubtypeAlbumRegular options:nil];
    [smartAlbums enumerateObjectsUsingBlock:^(PHAssetCollection *collection, NSUInteger idx, BOOL *stop) {
        PHFetchOptions *options = [[PHFetchOptions alloc] init];
        if (type == PickerTypeImage) {
            options.predicate = [NSPredicate predicateWithFormat:@"mediaType = %d", PHAssetMediaTypeImage];
        } else if (type == PickerTypeVideo) {
            options.predicate = [NSPredicate predicateWithFormat:@"mediaType = %d", PHAssetMediaTypeVideo];
        }
        PHFetchResult *assetsFetchResult = [PHAsset fetchAssetsInAssetCollection:collection options:options];
        if (assetsFetchResult.count > 0) {
            PLAssertGroupModel *assertGroupModel = [PLAssertGroupModel new];
            assertGroupModel.collection = assetsFetchResult;
            assertGroupModel.title = collection.localizedTitle;
            assertGroupModel.count = @(assetsFetchResult.count);
            [PLAssertGroupModelArray addObject:assertGroupModel];
        }
    }];
    
    PHFetchResult *topLevelUserCollections = [PHCollectionList fetchTopLevelUserCollectionsWithOptions:nil];
    for(PHCollection *collection in topLevelUserCollections)
    {
        if ([collection isKindOfClass:[PHAssetCollection class]])
        {
            PHFetchOptions *options = [[PHFetchOptions alloc] init];
            if (type == PickerTypeImage) {
                options.predicate = [NSPredicate predicateWithFormat:@"mediaType = %d", PHAssetMediaTypeImage];
            } else if (type == PickerTypeVideo) {
                options.predicate = [NSPredicate predicateWithFormat:@"mediaType = %d", PHAssetMediaTypeVideo];
            }
            PHAssetCollection *assetCollection = (PHAssetCollection *)collection;
            PHFetchResult *assetsFetchResult = [PHAsset fetchAssetsInAssetCollection:assetCollection options:options];
            if (assetsFetchResult.count > 0) {
                PLAssertGroupModel *assertGroupModel = [PLAssertGroupModel new];
                assertGroupModel.collection = assetsFetchResult;
                assertGroupModel.title = collection.localizedTitle;
                assertGroupModel.count = @(assetsFetchResult.count);
                [PLAssertGroupModelArray addObject:assertGroupModel];
            }
        }
    }
    
    block(PLAssertGroupModelArray);
}

+ (void)assertImage:(id)assert size:(CGSize)size usingBlock:(void (^)(UIImage *image, BOOL isGif))block isNeedCompressed:(BOOL)isNeedCompressed
{
    if ([[assert class] isSubclassOfClass:[PHFetchResult class]]) {
        assert = [assert lastObject];
    }
    if (size.width == 0 && size.height == 0) {
        size = PHImageManagerMaximumSize;
    }
    
    PHImageRequestOptions *options = [PHImageRequestOptions new];
    options.version = PHImageRequestOptionsVersionCurrent;
    options.deliveryMode = PHImageRequestOptionsDeliveryModeOpportunistic;
    options.resizeMode = PHImageRequestOptionsResizeModeNone;
    options.networkAccessAllowed = YES;
    options.synchronous = NO;
    
    __block BOOL isGif = NO;
    if ([[assert valueForKey:@"uniformTypeIdentifier"] isEqualToString:@"com.compuserve.gif"]) {
        isGif = YES;
    }
    
    [[PHImageManager defaultManager] requestImageForAsset:(PHAsset*)assert
                                               targetSize:size
                                              contentMode:PHImageContentModeAspectFill
                                                  options:options
                                            resultHandler:^(UIImage *result, NSDictionary *info) {
                                                /**
                                                 *  size 为 PHImageManagerMaximumSize，第一次回调压缩图，第二次回调全尺寸图，通过PHImageResultIsDegradedKey区别全尺寸图
                                                 */
                                                if ([[PLAssertManager contentTypeForImageData:UIImagePNGRepresentation(result)] isEqualToString:@"gif"]) {
                                                    isGif = YES;
                                                }
                                                
                                                if ([[info valueForKey:@"PHImageResultIsDegradedKey"] integerValue] == 0){
                                                    if (isNeedCompressed) {
                                                        NSData *imageData = UIImagePNGRepresentation(result);
                                                        if ([[UIDevice currentDevice] getTotalMemorySize] < 1024 * 1024 * 1024) {
                                                            //小于1G的设备,图片大于20m不让选
                                                            if ([imageData length] > 20 * 1024 * 1024) {
                                                                block(nil, isGif);
                                                                return;
                                                            }
                                                        } else {
                                                            //小于大于G的设备,图片大于50m不让选
                                                            if ([imageData length] > 50 * 1024 * 1024) {
                                                                block(nil, isGif);
                                                                return;
                                                            }
                                                        }
                                                        @autoreleasepool {
                                                            UIImage *compressedImage = [result compressImageWithRotate:YES];
                                                            block(compressedImage, isGif);
                                                        }
                                                    } else {
                                                        block(result, isGif);
                                                    }
                                                }
                                            }];
}

+ (void)assertImage:(id)assert size:(CGSize)size usingDataBlock:(void (^)(NSData *imageData, BOOL isGif))block isNeedCompressed:(BOOL)isNeedCompressed
{
    if ([[assert class] isSubclassOfClass:[PHFetchResult class]]) {
        assert = [assert lastObject];
    }
    if (size.width == 0 && size.height == 0) {
        size = PHImageManagerMaximumSize;
    } else {
        size = CGSizeMake(size.width * [[UIScreen mainScreen] scale], size.height * [[UIScreen mainScreen] scale]);
    }
    
    PHImageRequestOptions *options = [PHImageRequestOptions new];
    options.version = PHImageRequestOptionsVersionCurrent;
//    options.deliveryMode = PHImageRequestOptionsDeliveryModeHighQualityFormat;
    options.deliveryMode = PHImageRequestOptionsDeliveryModeFastFormat;

    options.resizeMode = PHImageRequestOptionsResizeModeNone;
    options.networkAccessAllowed = YES;
    options.synchronous = NO;
    
    [[PHImageManager defaultManager] requestImageDataForAsset:assert options:options resultHandler:^(NSData * _Nullable imageData, NSString * _Nullable dataUTI, UIImageOrientation orientation, NSDictionary * _Nullable info) {
        /**
         *  size 为 PHImageManagerMaximumSize，第一次回调压缩图，第二次回调全尺寸图，通过PHImageResultIsDegradedKey区别全尺寸图
         */
        
        if ([[PLAssertManager contentTypeForImageData:imageData] isEqualToString:@"gif"]) {
            if ([[info valueForKey:@"PHImageResultIsDegradedKey"] integerValue] == 0) {
                //动图不压缩
                block(imageData, YES);
            }
        } else {
            if ([[info valueForKey:@"PHImageResultIsDegradedKey"] integerValue] == 0){
                if (isNeedCompressed) {
                    if ([[UIDevice currentDevice] getTotalMemorySize] < 1024 * 1024 * 1024) {
                        //小于1G的设备,图片大于20m不让选
                        if ([imageData length] > 20 * 1024 * 1024) {
                            block(nil, NO);
                            return;
                        }
                    } else {
                        //小于大于G的设备,图片大于50m不让选
                        if ([imageData length] > 50 * 1024 * 1024) {
                            block(nil, NO);
                            return;
                        }
                    }
                    @autoreleasepool {
                        UIImage *compressedImage = [[UIImage imageWithData:imageData] compressImageWithRotate:YES];
                        block(UIImageJPEGRepresentation(compressedImage, 1.0), NO);
                    }
                } else {
                    block(imageData, NO);
                }
            }
        }
    }];
}

//通过图片Data数据第一个字节 来获取图片扩展名
+ (NSString *)contentTypeForImageData:(NSData *)data
{
    uint8_t c;
    [data getBytes:&c length:1];
    switch (c) {
        case 0xFF:
            return @"jpeg";
        case 0x89:
            return @"png";
        case 0x47:
            return @"gif";
        case 0x49:
        case 0x4D:
            return @"tiff";
        case 0x52:
            if ([data length] < 12) {
                return nil;
            }
            NSString *testString = [[NSString alloc] initWithData:[data subdataWithRange:NSMakeRange(0, 12)] encoding:NSASCIIStringEncoding];
            if ([testString hasPrefix:@"RIFF"] && [testString hasSuffix:@"WEBP"]) {
                return @"webp";
            }
            return nil;
    }
    return nil;
}

/**
 *  判断是否同一个Assert
 *
 *  @param assert     assert资源
 *  @param nextAssert 另外一个assert资源
 *
 *  @return YES / NO
 */
+ (BOOL)isEqulAssert:(id)assert nextAssert:(id)nextAssert
{
    PHAsset *phAssert = (PHAsset*)assert;
    PHAsset *phNextAssert = (PHAsset*)nextAssert;
    if (phAssert.hash == phNextAssert.hash) {
        return YES;
    } else {
        return NO;
    }
}

/**
 *  用相机拍摄出来的照片含有EXIF信息，需要对图片方向进行修正
 *
 */
+ (UIImage *)fixOrientation:(UIImage *)aImage {
    
    // No-op if the orientation is already correct
    if (aImage.imageOrientation == UIImageOrientationUp)
        return aImage;
    
    // We need to calculate the proper transformation to make the image upright.
    // We do it in 2 steps: Rotate if Left/Right/Down, and then flip if Mirrored.
    CGAffineTransform transform = CGAffineTransformIdentity;
    
    switch (aImage.imageOrientation) {
        case UIImageOrientationDown:
        case UIImageOrientationDownMirrored:
            transform = CGAffineTransformTranslate(transform, aImage.size.width, aImage.size.height);
            transform = CGAffineTransformRotate(transform, M_PI);
            break;
            
        case UIImageOrientationLeft:
        case UIImageOrientationLeftMirrored:
            transform = CGAffineTransformTranslate(transform, aImage.size.width, 0);
            transform = CGAffineTransformRotate(transform, M_PI_2);
            break;
            
        case UIImageOrientationRight:
        case UIImageOrientationRightMirrored:
            transform = CGAffineTransformTranslate(transform, 0, aImage.size.height);
            transform = CGAffineTransformRotate(transform, -M_PI_2);
            break;
        default:
            break;
    }
    
    switch (aImage.imageOrientation) {
        case UIImageOrientationUpMirrored:
        case UIImageOrientationDownMirrored:
            transform = CGAffineTransformTranslate(transform, aImage.size.width, 0);
            transform = CGAffineTransformScale(transform, -1, 1);
            break;
            
        case UIImageOrientationLeftMirrored:
        case UIImageOrientationRightMirrored:
            transform = CGAffineTransformTranslate(transform, aImage.size.height, 0);
            transform = CGAffineTransformScale(transform, -1, 1);
            break;
        default:
            break;
    }
    
    // Now we draw the underlying CGImage into a new context, applying the transform
    // calculated above.
    CGContextRef ctx = CGBitmapContextCreate(NULL, aImage.size.width, aImage.size.height,
                                             CGImageGetBitsPerComponent(aImage.CGImage), 0,
                                             CGImageGetColorSpace(aImage.CGImage),
                                             CGImageGetBitmapInfo(aImage.CGImage));
    CGContextConcatCTM(ctx, transform);
    switch (aImage.imageOrientation) {
        case UIImageOrientationLeft:
        case UIImageOrientationLeftMirrored:
        case UIImageOrientationRight:
        case UIImageOrientationRightMirrored:
            // Grr...
            CGContextDrawImage(ctx, CGRectMake(0,0,aImage.size.height,aImage.size.width), aImage.CGImage);
            break;
            
        default:
            CGContextDrawImage(ctx, CGRectMake(0,0,aImage.size.width,aImage.size.height), aImage.CGImage);
            break;
    }
    
    // And now we just create a new UIImage from the drawing context
    CGImageRef cgimg = CGBitmapContextCreateImage(ctx);
    UIImage *img = [UIImage imageWithCGImage:cgimg];
    CGContextRelease(ctx);
    CGImageRelease(cgimg);
    return img;
}

@end

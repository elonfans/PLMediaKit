//
//  UIImage+Extends.m
//  shenbian
//
//  Created by MagicYang on 2/26/11.
//  Copyright 2011 personal. All rights reserved.
//

#import "UIImage+PLExtends.h"

#define KOSWidth [UIScreen mainScreen].bounds.size.width
#define KOSHeight [UIScreen mainScreen].bounds.size.height

@implementation UIImage (Resizing)

- (UIImage*)transformWidth:(CGFloat)width height:(CGFloat)height rotate:(BOOL)rotate {
    CGFloat destW = width;
    CGFloat destH = height;
    CGFloat sourceW = width;
    CGFloat sourceH = height;
    if (rotate) {
        if (self.imageOrientation == UIImageOrientationRight
            || self.imageOrientation == UIImageOrientationLeft) {
            sourceW = height;
            sourceH = width;
        }
    }
    
    CGImageRef imageRef = self.CGImage;
    //modified by xhan, origin codes has bug deal with png files.
    // http://vocaro.com/trevor/blog/2009/10/12/resize-a-uiimage-the-right-way/comment-page-3/#comment-76692
    CGContextRef bitmap = CGBitmapContextCreate(NULL,
                                                destW,
                                                destH,
                                                8,//CGImageGetBitsPerComponent(imageRef),
                                                destW *4 ,//0,
                                                CGColorSpaceCreateDeviceRGB(),//CGImageGetColorSpace(imageRef),
                                                kCGImageAlphaPremultipliedLast
                                                //CGImageGetBitmapInfo(imageRef)
                                                );
    
    if (rotate) {
        if (self.imageOrientation == UIImageOrientationDown) {
            CGContextTranslateCTM(bitmap, sourceW, sourceH);
            CGContextRotateCTM(bitmap, 180 * (M_PI/180));
        } else if (self.imageOrientation == UIImageOrientationLeft) {
            CGContextTranslateCTM(bitmap, sourceH, 0);
            CGContextRotateCTM(bitmap, 90 * (M_PI/180));
        } else if (self.imageOrientation == UIImageOrientationRight) {
            CGContextTranslateCTM(bitmap, 0, sourceW);
            CGContextRotateCTM(bitmap, -90 * (M_PI/180));
        }
    }
    
    CGContextDrawImage(bitmap, CGRectMake(0,0,sourceW,sourceH), imageRef);
    
    CGImageRef ref = CGBitmapContextCreateImage(bitmap);
    UIImage* result = [UIImage imageWithCGImage:ref];
    CGContextRelease(bitmap);
    CGImageRelease(ref);
    
    return result;
}

// 图片压缩旋转
- (UIImage *)compressImageWithRotate:(BOOL)rotate
{
    NSInteger width = self.size.width;
    NSInteger height = self.size.height;

//    if (width > height) {
//        if (height > 2 * KOSHeight) {
//            height = 2 * KOSHeight;
//        }
//        width = height * width / self.size.height;
//    } else {
//        if (width > 2 * KOSWidth) {
//            width = 2 * KOSWidth;
//        }
//        height = width * height / self.size.width;
//    }
    
    width = width / 1.25;
    height = height / 1.25;
    
    CGFloat destW = width;
    CGFloat destH = height;
    CGFloat sourceW = width;
    CGFloat sourceH = height;
    if (rotate) {
        if (self.imageOrientation == UIImageOrientationRight
            || self.imageOrientation == UIImageOrientationLeft) {
            sourceW = height;
            sourceH = width;
        }
    }
    
	CGImageRef imageRef = self.CGImage;
    //modified by xhan, origin codes has bug deal with png files.
    // http://vocaro.com/trevor/blog/2009/10/12/resize-a-uiimage-the-right-way/comment-page-3/#comment-76692
	CGContextRef bitmap = CGBitmapContextCreate(NULL,
												destW,
												destH,
												8,//CGImageGetBitsPerComponent(imageRef),
												destW * 4 ,//0,
												CGColorSpaceCreateDeviceRGB(),//CGImageGetColorSpace(imageRef),
												kCGImageAlphaPremultipliedLast
                                                //CGImageGetBitmapInfo(imageRef)
                                                );
	
	if (rotate) {
		if (self.imageOrientation == UIImageOrientationDown) {
			CGContextTranslateCTM(bitmap, sourceW, sourceH);
			CGContextRotateCTM(bitmap, 180 * (M_PI/180));
		} else if (self.imageOrientation == UIImageOrientationLeft) {
			CGContextTranslateCTM(bitmap, sourceH, 0);
			CGContextRotateCTM(bitmap, 90 * (M_PI/180));
		} else if (self.imageOrientation == UIImageOrientationRight) {
			CGContextTranslateCTM(bitmap, 0, sourceW);
			CGContextRotateCTM(bitmap, -90 * (M_PI/180));
		}
	}
	CGContextDrawImage(bitmap, CGRectMake(0,0,sourceW,sourceH), imageRef);
	CGImageRef ref = CGBitmapContextCreateImage(bitmap);
	UIImage* result = [UIImage imageWithCGImage:ref];
	CGContextRelease(bitmap);
	CGImageRelease(ref);
    result = [UIImage imageWithData:UIImageJPEGRepresentation(result, 0.5)];
    return result;
}

// 长图
+ (BOOL)isLongImageWith:(CGFloat)width height:(CGFloat)height
{
    if (height > 2 * KOSHeight || width > 2 * KOSWidth) {
        if (height / width > 3) {
            return YES;
        } else if (width / height > 3) {
            return YES;
        }
    }
    return NO;
}

+ (UIImage *)compressImage:(UIImage *)image
             compressRatio:(CGFloat)ratio
{
    return [[self class] compressImage:image compressRatio:ratio maxCompressRatio:0.1f];
}

+ (UIImage *)compressImage:(UIImage *)image compressRatio:(CGFloat)ratio maxCompressRatio:(CGFloat)maxRatio
{
    
    //We define the max and min resolutions to shrink to
    CGRect bounds = [[UIScreen mainScreen] bounds];
    int MIN_UPLOAD_RESOLUTION = CGRectGetWidth(bounds) * CGRectGetHeight(bounds) * 3;
//    int MAX_UPLOAD_SIZE = 5000;
    
    float factor;
    float currentResolution = image.size.height * image.size.width;
    
    //We first shrink the image a little bit in order to compress it a little bit more
    if (currentResolution > MIN_UPLOAD_RESOLUTION) {
        factor = sqrt(currentResolution / MIN_UPLOAD_RESOLUTION);
        image = [self scaleDown:image withSize:CGSizeMake(image.size.width / factor, image.size.height / factor)];
    }
    
    //Compression settings
    CGFloat compression = ratio;
//    CGFloat maxCompression = 1;//maxRatio;
    
    //We loop into the image data to compress accordingly to the compression ratio
    NSData *imageData = UIImageJPEGRepresentation(image, compression);
//    while ([imageData length] > MAX_UPLOAD_SIZE && compression > maxCompression) {
//        compression -= 0.10;
//        imageData = UIImageJPEGRepresentation(image, compression);
//    }
    
    //Retuns the compressed image
    return [[UIImage alloc] initWithData:imageData];
}


+ (UIImage *)compressRemoteImage:(NSString *)url
                   compressRatio:(CGFloat)ratio
                maxCompressRatio:(CGFloat)maxRatio
{
    //Parse the URL
    NSURL *imageURL = [NSURL URLWithString:url];
    
    //We init the image with the rmeote data
    UIImage *remoteImage = [UIImage imageWithData:[NSData dataWithContentsOfURL:imageURL]];
    
    //Returns the remote image compressed
    return [[self class] compressImage:remoteImage compressRatio:ratio maxCompressRatio:maxRatio];
    
}

+ (UIImage *)compressRemoteImage:(NSString *)url compressRatio:(CGFloat)ratio
{
    return [[self class] compressRemoteImage:url compressRatio:ratio maxCompressRatio:0.1f];
}

+ (UIImage*)scaleDown:(UIImage*)image withSize:(CGSize)newSize
{
    
    //We prepare a bitmap with the new size
    UIGraphicsBeginImageContextWithOptions(newSize, YES, 0.0);
    
    //Draws a rect for the image
    [image drawInRect:CGRectMake(0, 0, newSize.width, newSize.height)];
    
    //We set the scaled image from the context
    UIImage* scaledImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return scaledImage;
}

// ------这种方法对图片既进行压缩，又进行裁剪
- (NSData *)imageWithImage:(UIImage*)image scaledToSize:(CGSize)newSize
{
    UIGraphicsBeginImageContext(newSize);
    [image drawInRect:CGRectMake(0,0,newSize.width,newSize.height)];
    UIImage* newImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return UIImageJPEGRepresentation(newImage, 0.8);
}

+ (UIImage *)imageWithColor:(UIColor *)color
{
    CGRect rect = CGRectMake(0.0f, 0.0f, 1.0f, 1.0f);
    UIGraphicsBeginImageContext(rect.size);
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    CGContextSetFillColorWithColor(context, [color CGColor]);
    CGContextFillRect(context, rect);
    
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return image;
}

@end

//
//  HKPreviewView.m
//  HKMediaRecorderKit
//
//  Created by HuangKai on 15/11/2.
//  Copyright © 2015年 KayWong. All rights reserved.
//

#import "PLHKPreviewView.h"

@import AVFoundation;
@implementation PLHKPreviewView

+ (Class)layerClass
{
    return [AVCaptureVideoPreviewLayer class];
}
- (instancetype)init
{
    self = [super init];
    if (self) {
//        previewLayer.connection.videoOrientation = AVCaptureVideoOrientationPortrait;
//        previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
        if ([NSString instancesRespondToSelector:@selector(containsString:)]) {
            self.layer.hidden = YES;
            [self.layer addObserver:self forKeyPath:@"connection.videoOrientation" options:NSKeyValueObservingOptionNew context:NULL];
        }

    }
    return self;
}
- (AVCaptureSession *)session
{
    AVCaptureVideoPreviewLayer *previewLayer = (AVCaptureVideoPreviewLayer *)self.layer;
    return previewLayer.session;
}
- (void)dealloc{
    if ([NSString instancesRespondToSelector:@selector(containsString:)]) {
        [self.layer removeObserver:self forKeyPath:@"connection.videoOrientation"];
    }
}
- (void)setSession:(AVCaptureSession *)session
{
    AVCaptureVideoPreviewLayer *previewLayer = (AVCaptureVideoPreviewLayer *)self.layer;
    previewLayer.session = session;
}
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context{
    if ([NSString instancesRespondToSelector:@selector(containsString:)]) {
        id newValue = change[NSKeyValueChangeNewKey];
        if([newValue isKindOfClass:[NSNumber class]] && [newValue integerValue] == AVCaptureVideoOrientationPortrait && self.layer.hidden == YES){
            [self performSelector:@selector(showPreViewLayer) withObject:nil afterDelay:0.5];
        }    }


}
- (void)showPreViewLayer{
    self.layer.hidden = NO;
}
@end

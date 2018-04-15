//
//  HKPreviewView.h
//  HKMediaRecorderKit
//
//  Created by HuangKai on 15/11/2.
//  Copyright © 2015年 KayWong. All rights reserved.
//

#import <UIKit/UIKit.h>
@class AVCaptureSession;

@interface PLHKPreviewView : UIView

@property (nonatomic) AVCaptureSession *session;

@end

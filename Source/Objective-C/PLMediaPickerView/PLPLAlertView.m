//
//  PLAlertView.m
//  QiuBai
//
//  Created by xu xhan on 12/17/11.
//  Copyright (c) 2011 Less Everything. All rights reserved.
//

#import "PLPLAlertView.h"

@implementation _PLPLAlertView

- (void)setBlock:(void (^)(int,BOOL))block;
{
    _blockDelegate = block;
    self.delegate = self;
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if(_blockDelegate)
    _blockDelegate((int)buttonIndex,alertView.cancelButtonIndex == buttonIndex);
}

- (void)dealloc
{
}
@end


extern void PLPLAlert(NSString*title,NSString*body,NSString*cancel,NSString*button,void (^block)(int index,BOOL isCancel))
{
    _PLPLAlertView *v= [[_PLPLAlertView alloc] initWithTitle:title
                                                        message:body
                                                       delegate:nil
                                              cancelButtonTitle:cancel
                                              otherButtonTitles:button,nil];
    [v setBlock:block];
    [v show];    
}

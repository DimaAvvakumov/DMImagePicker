//
//  DMImagePickerPreviewView.h
//  DMImagePicker
//
//  Created by Avvakumov Dmitry on 24.08.15.
//  Copyright (c) 2015 Avvakumov Dmitry. All rights reserved.
//

#import <UIKit/UIKit.h>

@class AVCaptureSession;

@interface DMImagePickerPreviewView : UIView

@property (nonatomic) AVCaptureSession *session;

@end

//
//  DMImagePickerPreviewView.m
//  DMImagePicker
//
//  Created by Avvakumov Dmitry on 24.08.15.
//  Copyright (c) 2015 Avvakumov Dmitry. All rights reserved.
//

#import "DMImagePickerPreviewView.h"

#import <AVFoundation/AVFoundation.h>

@implementation DMImagePickerPreviewView

+ (Class)layerClass {
    return [AVCaptureVideoPreviewLayer class];
}

- (AVCaptureSession *)session {
    return [(AVCaptureVideoPreviewLayer *)[self layer] session];
}

- (void)setSession:(AVCaptureSession *)session {
    AVCaptureVideoPreviewLayer *layer = (AVCaptureVideoPreviewLayer *) [self layer];
    [layer setSession:session];
    
    layer.videoGravity = AVLayerVideoGravityResizeAspectFill;
}

@end

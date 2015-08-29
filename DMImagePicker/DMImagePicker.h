//
//  DMImagePicker.h
//  DMImagePicker
//
//  Created by Avvakumov Dmitry on 24.08.15.
//  Copyright (c) 2015 Avvakumov Dmitry. All rights reserved.
//

#import <UIKit/UIKit.h>

@class DMImagePicker;
@protocol DMImagePickerDelegate <NSObject>
@optional

- (void)dmImagePicker:(DMImagePicker *)picker takeImage:(UIImage *)image;
- (void)dmImagePicker:(DMImagePicker *)picker takeVideo:(NSURL *)videoURL;
- (void)dmImagePickerCancel:(DMImagePicker *)picker;

@end

@interface DMImagePicker : UIViewController

@property (weak, nonatomic) id<DMImagePickerDelegate> delegate;

@property (assign, nonatomic) CGFloat aspectRatio;

@end

//
//  DMImageEditViewController.h
//  DMImagePicker
//
//  Created by Avvakumov Dmitry on 24.08.15.
//  Copyright (c) 2015 Avvakumov Dmitry. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef void (^DMImageEditViewControllerDoneBlock)(UIImage *image);
typedef void (^DMImageEditViewControllerCancelBlock)(void);

@interface DMImageEditViewController : UIViewController

@property (copy, nonatomic) DMImageEditViewControllerDoneBlock doneBlock;
@property (copy, nonatomic) DMImageEditViewControllerCancelBlock cancelBlock;

@property (strong, nonatomic) UIImage *originalImage;

@end

//
//  ViewController.m
//  DMImagePicker
//
//  Created by Avvakumov Dmitry on 24.08.15.
//  Copyright (c) 2015 Avvakumov Dmitry. All rights reserved.
//

#import "ViewController.h"

#import "DMImagePicker.h"

@interface ViewController () <DMImagePickerDelegate>

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)takePhoto:(UIButton*)sender {
    
    DMImagePicker *imagePicker = [[DMImagePicker alloc] init];
    imagePicker.delegate = self;
    [self presentViewController:imagePicker animated:YES completion:nil];
    
}

#pragma mark - DMImagePickerDelegate

- (void)dmImagePickerCancel:(DMImagePicker *)picker {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)dmImagePicker:(DMImagePicker *)picker takeImage:(UIImage *)image {
    [self dismissViewControllerAnimated:YES completion:nil];
    
    NSLog(@"image: %@", image);
    NSLog(@"image orient: %d", image.imageOrientation);
}

@end

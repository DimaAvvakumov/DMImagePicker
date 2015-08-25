# DMImagePicker
Custom camera picker for ios

## Installation

1. Simple drag and drop DMImagePicker folder in you project
2. Add header file 

```objectiv-c
#import "DMImagePicker.h"
```

## Architecture

- `DMImagePicker`

## Usage

### First example

For showing alert view into you UIViewController just do this:

```objectiv-c
  // create picker
  DMImagePicker *imagePicker = [[DMImagePicker alloc] init];
  imagePicker.delegate = self;
  [self presentViewController:imagePicker animated:YES completion:nil];
```

### DMImagePickerDelegate

This class has some delegate methods

```objectiv-c
  - (void)dmImagePickerCancel:(DMImagePicker *)picker {
    [self dismissViewControllerAnimated:YES completion:nil];
  }
```

and

```objectiv-c
  - (void)dmImagePicker:(DMImagePicker *)picker takeImage:(UIImage *)image {
    [self dismissViewControllerAnimated:YES completion:nil];
    
    NSLog(@"image: %@", image);
    NSLog(@"image orient: %d", image.imageOrientation);
  }
```




//
//  DMImageEditViewController.m
//  DMImagePicker
//
//  Created by Avvakumov Dmitry on 24.08.15.
//  Copyright (c) 2015 Avvakumov Dmitry. All rights reserved.
//

#import "DMImageEditViewController.h"

#define DMImageEditViewController_MaxScale 2.0

@interface DMImageEditViewController () {
    float _minScale;
    float _maxScale;
    float _renderScale;
    
    CGPoint _zoomRelationPos;
}

@property (weak, nonatomic) IBOutlet UIScrollView *scrollView;
@property (weak, nonatomic) IBOutlet UIImageView *imageView;

@property (assign, nonatomic) CGSize storeImageSize;

@end

@implementation DMImageEditViewController

#pragma mark - Init methods

- (id)init {
    self = [super initWithNibName:@"DMImageEditViewController" bundle:nil];
    if (self == nil) return nil;
    
    // init controller
    [self initController];
    
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if (self == nil) return nil;
    
    // init controller
    [self initController];
    
    return self;
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self == nil) return nil;
    
    // init controller
    [self initController];
    
    return self;
}

- (void)initController {
    _minScale = 1.0;
    _maxScale = 1.0;
    _renderScale = 1.0;

}

- (void)dealloc {
    
}

#pragma mark - View cicle

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.storeImageSize = self.originalImage.size;
    
    [self buildView];
    
    [self recalculateScale];
    [self resetScaleAnimated:NO];
}

- (void) willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {
    
    [self recalculateScale];
    [self resetScaleAnimated:NO];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Status bar

- (BOOL)prefersStatusBarHidden {
    return YES;
}

- (BOOL)shouldAutorotate {
    return YES;
}

- (NSUInteger)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskAll;
}

#pragma mark - Build view

- (void) buildView {
    // set slide to image view
    [self setupImage:self.originalImage];
}

- (void) restrictScaleByFrame {
    [self recalculateScale];
    [self resetScaleAnimated:NO];
}

- (void) setupImage: (UIImage *) image {
    // bind image
    [_imageView setImage: image];
    
    // update image frame
    CGRect frame = _imageView.frame;
    frame.size = image.size;
    [_imageView setFrame:frame];
    
}

- (void) recalculateScale {
    if (self.originalImage == nil) return;
    
    // image size
    CGFloat imageWidth = _storeImageSize.width;
    CGFloat imageHeight = _storeImageSize.height;
    if (imageWidth == 0.0 || imageHeight == 0.0) return;
    
    // calc scale
    CGFloat scale1 = _scrollView.frame.size.width / _storeImageSize.width;
    CGFloat scale2 = _scrollView.frame.size.height / _storeImageSize.height;
    CGFloat minScale = MIN(scale1, scale2);
    CGFloat maxScale = DMImageEditViewController_MaxScale;
    if (minScale > DMImageEditViewController_MaxScale) {
        maxScale = minScale;
    }
    
    _minScale = minScale;
    _maxScale = maxScale;
}

- (void) resetScaleAnimated: (BOOL) animated {
    _renderScale = _minScale;
    
    [self setMaketToScale:_renderScale animated:animated];
}

#pragma mark - Zoom methods

- (IBAction)doubleTapHandler:(UITapGestureRecognizer *)sender {
    if (sender.state != UIGestureRecognizerStateEnded) return;
    
    CGPoint startPos = [sender locationInView: _imageView];
    _zoomRelationPos.x = startPos.x / _imageView.frame.size.width;
    _zoomRelationPos.y = startPos.y / _imageView.frame.size.height;
    
    CGFloat zoomScale = _minScale;
    if (_renderScale == _minScale) {
        zoomScale = _maxScale;
    }
    
    [self setMaketToScale:zoomScale animated:YES];
}

#pragma mark - Gestures

- (IBAction) pinchHandler:(UIPinchGestureRecognizer *)sender {
    //NSLog(@"Pinch scale: %f,\tvelocity: %f", sender.scale, sender.velocity);
    
    static CGFloat zoomScale;
    
    switch (sender.state) {
        case UIGestureRecognizerStateBegan: {
            
            CGPoint startPos = [sender locationInView: _imageView];
            _zoomRelationPos.x = startPos.x / _imageView.frame.size.width;
            _zoomRelationPos.y = startPos.y / _imageView.frame.size.height;
            
            break;
        }
        case UIGestureRecognizerStateChanged: {
            float scale = sender.scale;
            float newScale = [self scaleByPinchScale: scale];
            [self changeZoom: newScale];
            
            zoomScale = newScale;
            
            break;
        }
        case UIGestureRecognizerStateEnded: {
            //            float scale = recognizer.scale;
            //            float newScale = [self scaleByPinchScale: scale];
            //
            //            float velocity = recognizer.velocity;
            //            BOOL buttonVisible = YES;
            //            if (newScale >= _maxScale - 0.1) {
            //                if (velocity <= 0.0) {
            //                    newScale = _minScale;
            //                } else {
            //                    newScale = _maxScale;
            //                    buttonVisible = NO;
            //                }
            //            } else {
            //                if (velocity >= 0.0) {
            //                    newScale = _maxScale;
            //                    buttonVisible = NO;
            //                } else {
            //                    newScale = _minScale;
            //                }
            //            }
            
            [self setMaketToScale:zoomScale animated:YES];
            
            break;
        }
        default:
            break;
    }
}

- (float) scaleByPinchScale: (float) scale {
    // NSLog(@"sc: %f", scale);
    // float deltaScale = _maxScale - _minScale;
    float newScale = 1.0;
    if (scale > 1.0) {
        newScale = _renderScale * scale;
    } else {
        newScale = _renderScale * scale;
    }
    
    //float newScale = _renderScale + (scale - 1.0) * deltaScale;
    
    //    float newScale = _renderScale + (scale - 1.0);
    
//    if (newScale < _minScale) {
//        newScale = _minScale;
//    }
//    if (newScale > _maxScale) {
//        newScale = _maxScale;
//    }
    
    return newScale;
}

- (void) setMaketToScale: (float) scale animated: (BOOL) animated {
    if (scale < _minScale) scale = _minScale;
    if (scale > _maxScale) scale = _maxScale;
    
    // background image
    //    UIInterfaceOrientation orientation = renderOrienation;
    NSTimeInterval duration = 0.3;
    
    if (animated) {
        [UIView animateWithDuration:duration animations:^{
            
            // change zooming
            [self changeZoom: scale];
        } completion:^(BOOL finished) {
            [self resizeMaketToScale: scale];
        }];
    } else {
        
        // change zooming
        [self changeZoom: scale];
        
        [self resizeMaketToScale: scale];
    }
}

- (void) changeZoom: (float) scale {
    // UIInterfaceOrientation orientation = renderOrienation;
    // CGSize screenSize = [[UIDevice currentDevice] screenSizeForOrientation: orientation];
    CGSize screenSize = _scrollView.bounds.size;
    // BOOL isLandscape = (UIInterfaceOrientationIsLandscape(orientation)) ? YES : NO;
    // BOOL isPortrait = !isLandscape;
    CGSize imageSize = _storeImageSize;
    
    CGSize scrollContentSize = [self scaleSize:imageSize toScale:scale];
    float contentWidth  = scrollContentSize.width;
    float contentHeight = scrollContentSize.height;
    float scaleProportion = scale / _renderScale;
    
    // transform content view
    CGAffineTransform t = CGAffineTransformMakeScale(scaleProportion, scaleProportion);
    [_imageView setTransform: t];
    
    // scroll settings
    CGPoint scrollOffset = CGPointZero;
    CGSize scrollSize;
    CGPoint contentCenter = CGPointZero;
    if (contentWidth > screenSize.width) {
        scrollSize.width = contentWidth;
        contentCenter.x = roundf(scrollSize.width / 2.0);
        scrollOffset.x = roundf(contentWidth * _zoomRelationPos.x - screenSize.width / 2.0);
    } else {
        scrollSize.width = screenSize.width;
        contentCenter.x = roundf(scrollSize.width / 2.0);
    }
    if (contentHeight > screenSize.height) {
        scrollSize.height = contentHeight;
        contentCenter.y = roundf(scrollSize.height / 2.0);
        scrollOffset.y = roundf(contentHeight * _zoomRelationPos.y - screenSize.height / 2.0);
    } else {
        scrollSize.height = screenSize.height;
        contentCenter.y = roundf(scrollSize.height / 2.0);
    }
    //    if (isPortrait) {
    //        float deltaScale = _maxScale - _minScale;
    //        float percent = (scale - _minScale) / deltaScale;
    //
    //        scrollOffset.x = -10.0 * percent + (scrollSize.width  - _scrollView.frame.size.width) / 2.0;
    //        scrollOffset.y = (scrollSize.height - _scrollView.frame.size.height) / 2.0;
    //    }
    
    // check scroll offset
    float maxOffsetX = scrollSize.width  - screenSize.width;
    float maxOffsetY = scrollSize.height - screenSize.height;
    if (scrollOffset.x < 0.0) scrollOffset.x = 0.0;
    if (maxOffsetX > 0 && scrollOffset.x > maxOffsetX) scrollOffset.x = maxOffsetX;
    if (scrollOffset.y < 0.0) scrollOffset.y = 0.0;
    if (maxOffsetY > 0 && scrollOffset.y > maxOffsetY) scrollOffset.y = maxOffsetY;
    
    [_scrollView setContentSize: scrollSize];
    [_scrollView setContentOffset: scrollOffset animated: NO];
    [_imageView setCenter:contentCenter];
}

- (CGSize) scaleSize: (CGSize) size toScale: (float) scale {
    
    size.width  = roundf(scale * size.width);
    size.height = roundf(scale * size.height);
    
    return size;
}

- (void) resizeMaketToScale: (float) scale {
    // background image
    // UIInterfaceOrientation orientation = renderOrienation;
    // BOOL isLandscape = (UIInterfaceOrientationIsLandscape(orientation)) ? YES : NO;
    // BOOL isPortrait = !isLandscape;
    // CGSize screenSize = [[UIDevice currentDevice] screenSizeForOrientation: orientation];
    CGSize screenSize = _scrollView.bounds.size;
    // identity matrix
    CGAffineTransform t = CGAffineTransformIdentity;
    // scale proportion
    // float scaleProportion = scale / _renderScale;
    
    // render scale
    _renderScale = scale;
    
    // content size
    CGRect scrollContentRect = CGRectZero;
    scrollContentRect.size = [self scaleSize:_storeImageSize toScale:scale];
    [_imageView setTransform: t];
    [_imageView setFrame: scrollContentRect];
    
    // scroll settings
    BOOL scrollEnabled = YES;
    CGSize scrollSize;
    CGPoint scrollOffset = CGPointZero;
    if (scrollContentRect.size.width > screenSize.width) {
        scrollSize.width = scrollContentRect.size.width;
        scrollOffset.x = roundf(scrollContentRect.size.width * _zoomRelationPos.x - (screenSize.width / 2.0));
    } else {
        scrollSize.width = screenSize.width;
        scrollContentRect.origin.x = roundf((screenSize.width - scrollContentRect.size.width) / 2.0);
    }
    if (scrollContentRect.size.height > screenSize.height) {
        scrollSize.height = scrollContentRect.size.height;
        scrollOffset.y = roundf(scrollContentRect.size.height * _zoomRelationPos.y - (screenSize.height / 2.0));
    } else {
        scrollSize.height = screenSize.height;
        scrollContentRect.origin.y = roundf((screenSize.height - scrollContentRect.size.height) / 2.0);
    }
    //    if (isPortrait) {
    //        float deltaScale = _maxScale - _minScale;
    //        float percent = (scale - _minScale) / deltaScale;
    //
    //        scrollOffset.x = -10.0 * percent + (scrollSize.width  - _scrollView.frame.size.width) / 2.0;
    //        scrollOffset.y = (scrollSize.height - _scrollView.frame.size.height) / 2.0;
    //
    //        scrollEnabled = NO;
    //    }
    
    // check scroll offset
    float maxOffsetX = scrollSize.width  - screenSize.width;
    float maxOffsetY = scrollSize.height - screenSize.height;
    if (scrollOffset.x < 0.0) scrollOffset.x = 0.0;
    if (maxOffsetX > 0 && scrollOffset.x > maxOffsetX) scrollOffset.x = maxOffsetX;
    if (scrollOffset.y < 0.0) scrollOffset.y = 0.0;
    if (maxOffsetY > 0 && scrollOffset.y > maxOffsetY) scrollOffset.y = maxOffsetY;
    
    [_scrollView setContentSize:scrollSize];
    [_scrollView setContentOffset:scrollOffset animated:NO];
    [_scrollView setScrollEnabled: scrollEnabled];
    
    [_imageView setFrame: scrollContentRect];
    
    // scroll settings
    //    CGSize scrollSize = (isLandscape) ? CGSizeMake(480.0 + 2.0 * offsetLeft, 320.0) : screenSize;
    //    scrollSize.width  = scale * scrollSize.width;
    //    scrollSize.height = scale * scrollSize.height;
    //    [_scrollView setContentSize: scrollSize];
    //    [_scrollView setScrollEnabled: isLandscape];
}

#pragma mark - Retake action

- (IBAction)retakeAction:(UIButton*)sender {
    if (self.cancelBlock) {
        self.cancelBlock();
    }
}

- (IBAction)rotateAction:(UIButton*)sender {
    UIImage *image = [self rotateImage:self.originalImage];
    
    self.originalImage = image;
    self.storeImageSize = image.size;
    
    [self buildView];
    [self recalculateScale];
    [self resetScaleAnimated:NO];
}

- (IBAction)doneAction:(UIButton*)sender {
    if (self.doneBlock) {
        self.doneBlock( self.originalImage );
    }
}

#pragma mark - Helper actions

- (UIImage *)rotateImage:(UIImage *)image {
    
    CGSize size = CGSizeMake(image.size.height, image.size.width);
    // CGSize size = CGSizeMake(image.size.width, image.size.height);
    UIGraphicsBeginImageContext(size);
    
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    CGContextTranslateCTM( context, 0.5f * image.size.height, 0.5f * image.size.width ) ;
    CGContextRotateCTM (context, - M_PI_2);
    CGContextTranslateCTM( context, - 0.5f * image.size.width, - 0.5f * image.size.height ) ;
    
    // CGContextDrawImage(context, CGRectMake(0.0, 0.0, src.size.width, src.size.height), src.CGImage);
    
    [image drawAtPoint:CGPointMake(0, 0)];
    
    UIImage *rotatedImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return rotatedImage;
}

@end

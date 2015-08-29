//
//  DMImagePicker.m
//  DMImagePicker
//
//  Created by Avvakumov Dmitry on 24.08.15.
//  Copyright (c) 2015 Avvakumov Dmitry. All rights reserved.
//

#import "DMImagePicker.h"

#import <AVFoundation/AVFoundation.h>

#import "DMImagePickerPreviewView.h"

// controllers
#import "DMImageEditViewController.h"

static void * CapturingStillImageContext = &CapturingStillImageContext;
static void * RecordingContext = &RecordingContext;
static void * SessionRunningAndDeviceAuthorizedContext = &SessionRunningAndDeviceAuthorizedContext;

UIImage* DMImagePickerImageRotate(UIImage* image) {
    CGSize size = CGSizeMake(image.size.width, image.size.height);
    UIGraphicsBeginImageContext(size);
    
    [image drawAtPoint:CGPointMake(0, 0)];
    
    UIImage *rotatedImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

    return rotatedImage;
}

@interface DMImagePicker() <AVCaptureFileOutputRecordingDelegate>

// preview
@property (weak, nonatomic) IBOutlet UIView *previewWrapper;
@property (weak, nonatomic) IBOutlet DMImagePickerPreviewView *previewView;
@property (nonatomic, weak) IBOutlet NSLayoutConstraint *previewWidthConstraint;
@property (nonatomic, weak) IBOutlet NSLayoutConstraint *previewHeightConstraint;

// buttons
@property (nonatomic, weak) IBOutlet UIButton *shotButton;
@property (nonatomic, weak) IBOutlet UIButton *swapButton;
@property (nonatomic, weak) IBOutlet UIButton *cancelButton;

// Session management.
@property (nonatomic) dispatch_queue_t sessionQueue; // Communicate with the session and other session objects on this queue.
@property (nonatomic) AVCaptureSession *session;
@property (nonatomic) AVCaptureDeviceInput *videoDeviceInput;
@property (nonatomic) AVCaptureMovieFileOutput *movieFileOutput;
@property (nonatomic) AVCaptureStillImageOutput *stillImageOutput;

// Utilities.
@property (nonatomic) UIBackgroundTaskIdentifier backgroundRecordingID;
@property (nonatomic, getter = isDeviceAuthorized) BOOL deviceAuthorized;
@property (nonatomic, readonly, getter = isSessionRunningAndDeviceAuthorized) BOOL sessionRunningAndDeviceAuthorized;
@property (nonatomic) BOOL lockInterfaceRotation;
@property (nonatomic) id runtimeErrorHandlingObserver;

// Runtime
@property (nonatomic, assign) UIInterfaceOrientation interfaceOrientation;

@end

@implementation DMImagePicker

#pragma mark - Init methods

- (id)init {
//    NSURL *bundlePath = [[NSBundle bundleForClass:[self class]] URLForResource:@"DMImagePickerBundle" withExtension:@"bundle"];
//    NSBundle *bundle = [NSBundle bundleWithURL:bundlePath];
    
    self = [super initWithNibName:@"DMImagePicker" bundle:nil];
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
//    NSURL *bundlePath = [[NSBundle bundleForClass:[self class]] URLForResource:@"DMImagePickerBundle" withExtension:@"bundle"];
//    NSBundle *bundle = [NSBundle bundleWithURL:bundlePath];
    
    self = [super initWithNibName:nibNameOrNil bundle:nil];
    if (self == nil) return nil;
    
    // init controller
    [self initController];
    
    return self;
}

- (void)initController {
    self.interfaceOrientation = UIInterfaceOrientationPortrait;
}

- (void)dealloc {
    
}

#pragma mark - UI

- (void)deviceChangeOrientation:(NSNotification*)notification {
    UIDevice *device = notification.object;
    
    [self updateUIWithOrientation:(UIInterfaceOrientation)device.orientation animated:YES];
}

- (void)updateUIWithOrientation: (UIInterfaceOrientation) interfaceOrientation animated:(BOOL)animated {
    if (interfaceOrientation == UIInterfaceOrientationUnknown) return;
    if (interfaceOrientation > 4) return;
    
    self.interfaceOrientation = interfaceOrientation;
    
    CGAffineTransform transform = CGAffineTransformIdentity;
    if (interfaceOrientation == UIInterfaceOrientationLandscapeLeft) {
        transform = CGAffineTransformMakeRotation(- M_PI_2);
    } else if (interfaceOrientation == UIInterfaceOrientationLandscapeRight) {
        transform = CGAffineTransformMakeRotation(M_PI_2);
    } else if (interfaceOrientation == UIInterfaceOrientationPortraitUpsideDown) {
        transform = CGAffineTransformMakeRotation(M_PI);
    }
    
    // update preview screen
    if (self.aspectRatio > 0) {
        // preview ratio
        CGFloat w, h;
        CGFloat wrapper_w = self.previewWrapper.bounds.size.width;
        CGFloat wrapper_h = self.previewWrapper.bounds.size.height;
        CGFloat previewRatio = wrapper_w / wrapper_h;
        if (UIInterfaceOrientationIsLandscape(interfaceOrientation)) {
            previewRatio = self.previewWrapper.bounds.size.height / self.previewWrapper.bounds.size.width;
        }
        
        
        
        if (self.aspectRatio > previewRatio) {
            w = wrapper_w;
            h = roundf(w / self.aspectRatio);
        } else {
            h = wrapper_h;
            w = self.aspectRatio * h;
        }
        
        self.previewWidthConstraint.constant = w;
        self.previewHeightConstraint.constant = h;
    } else {
        self.previewWidthConstraint.constant = self.previewWrapper.bounds.size.width;
        self.previewHeightConstraint.constant = self.previewWrapper.bounds.size.height;
    }
    
    if (animated) {
        [UIView animateWithDuration:0.3 delay:0.0 options:UIViewAnimationOptionBeginFromCurrentState animations:^{
            self.cancelButton.transform = transform;
            self.swapButton.transform = transform;
            
            [self.previewView layoutIfNeeded];
        } completion:nil];
    } else {
        self.cancelButton.transform = transform;
        self.swapButton.transform = transform;
        
        [self.previewView layoutIfNeeded];
    }
    
}

#pragma mark - Sessions

- (BOOL)isSessionRunningAndDeviceAuthorized {
    return [[self session] isRunning] && [self isDeviceAuthorized];
}

+ (NSSet *)keyPathsForValuesAffectingSessionRunningAndDeviceAuthorized {
    return [NSSet setWithObjects:@"session.running", @"deviceAuthorized", nil];
}

#pragma mark - View cicle

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Create the AVCaptureSession
    AVCaptureSession *session = [[AVCaptureSession alloc] init];
    [self setSession:session];
    
    // Setup the preview view
    [[self previewView] setSession:session];
    
    // Check for device authorization
    [self checkDeviceAuthorizationStatus];
    
    // In general it is not safe to mutate an AVCaptureSession or any of its inputs, outputs, or connections from multiple threads at the same time.
    // Why not do all of this on the main queue?
    // -[AVCaptureSession startRunning] is a blocking call which can take a long time. We dispatch session setup to the sessionQueue so that the main queue isn't blocked (which keeps the UI responsive).
    
    dispatch_queue_t sessionQueue = dispatch_queue_create("session queue", DISPATCH_QUEUE_SERIAL);
    [self setSessionQueue:sessionQueue];
    
    dispatch_async(sessionQueue, ^{
        [self setBackgroundRecordingID:UIBackgroundTaskInvalid];
        
        NSError *error = nil;
        
        AVCaptureDevice *videoDevice = [DMImagePicker deviceWithMediaType:AVMediaTypeVideo preferringPosition:AVCaptureDevicePositionBack];
        AVCaptureDeviceInput *videoDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:videoDevice error:&error];
        
        if (error) {
            NSLog(@"%@", error);
        }
        
        if ([session canAddInput:videoDeviceInput]) {
            [session addInput:videoDeviceInput];
            [self setVideoDeviceInput:videoDeviceInput];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                // Why are we dispatching this to the main queue?
                // Because AVCaptureVideoPreviewLayer is the backing layer for AVCamPreviewView and UIView can only be manipulated on main thread.
                // Note: As an exception to the above rule, it is not necessary to serialize video orientation changes on the AVCaptureVideoPreviewLayer’s connection with other session manipulation.
                
                UIInterfaceOrientation interfaceOrientation = [[UIApplication sharedApplication] statusBarOrientation];
                [[(AVCaptureVideoPreviewLayer *)[[self previewView] layer] connection] setVideoOrientation:(AVCaptureVideoOrientation)interfaceOrientation];
            });
        }
        
        AVCaptureDevice *audioDevice = [[AVCaptureDevice devicesWithMediaType:AVMediaTypeAudio] firstObject];
        AVCaptureDeviceInput *audioDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:audioDevice error:&error];
        
        if (error) {
            NSLog(@"%@", error);
        }
        
        if ([session canAddInput:audioDeviceInput]) {
            [session addInput:audioDeviceInput];
        }
        
        AVCaptureMovieFileOutput *movieFileOutput = [[AVCaptureMovieFileOutput alloc] init];
        if ([session canAddOutput:movieFileOutput]) {
            [session addOutput:movieFileOutput];
            AVCaptureConnection *connection = [movieFileOutput connectionWithMediaType:AVMediaTypeVideo];
            if ([connection isVideoStabilizationSupported]) {
                if ([connection respondsToSelector:@selector(setPreferredVideoStabilizationMode:)]) {
                    connection.preferredVideoStabilizationMode = AVCaptureVideoStabilizationModeStandard;
                } else {
                    [connection setEnablesVideoStabilizationWhenAvailable:YES];
                }
            }
            [self setMovieFileOutput:movieFileOutput];
        }
        
        AVCaptureStillImageOutput *stillImageOutput = [[AVCaptureStillImageOutput alloc] init];
        if ([session canAddOutput:stillImageOutput]) {
            [stillImageOutput setOutputSettings:@{AVVideoCodecKey : AVVideoCodecJPEG}];
            [session addOutput:stillImageOutput];
            [self setStillImageOutput:stillImageOutput];
        }
    });
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    UIDevice *currentDevice = [UIDevice currentDevice];
    [currentDevice beginGeneratingDeviceOrientationNotifications];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(deviceChangeOrientation:) name:UIDeviceOrientationDidChangeNotification object:[UIDevice currentDevice]];
    
    dispatch_async([self sessionQueue], ^{
        [self addObserver:self forKeyPath:@"sessionRunningAndDeviceAuthorized" options:(NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew) context:SessionRunningAndDeviceAuthorizedContext];
        [self addObserver:self forKeyPath:@"stillImageOutput.capturingStillImage" options:(NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew) context:CapturingStillImageContext];
        [self addObserver:self forKeyPath:@"movieFileOutput.recording" options:(NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew) context:RecordingContext];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(subjectAreaDidChange:) name:AVCaptureDeviceSubjectAreaDidChangeNotification object:[[self videoDeviceInput] device]];
        
        __weak DMImagePicker *weakSelf = self;
        [self setRuntimeErrorHandlingObserver:[[NSNotificationCenter defaultCenter] addObserverForName:AVCaptureSessionRuntimeErrorNotification object:[self session] queue:nil usingBlock:^(NSNotification *note) {
            DMImagePicker *strongSelf = weakSelf;
            dispatch_async([strongSelf sessionQueue], ^{
                // Manually restarting the session since it must have been stopped due to an error.
                [[strongSelf session] startRunning];
                // [[strongSelf recordButton] setTitle:NSLocalizedString(@"Record", @"Recording button record title") forState:UIControlStateNormal];
            });
        }]];
        [[self session] startRunning];
    });
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    UIDevice *currentDevice = [UIDevice currentDevice];
    
    // update interface buttons
    [self updateUIWithOrientation:(UIInterfaceOrientation)currentDevice.orientation animated:YES];

}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    
    [[UIDevice currentDevice] endGeneratingDeviceOrientationNotifications];
    
    dispatch_async([self sessionQueue], ^{
        [[self session] stopRunning];
        
        [[NSNotificationCenter defaultCenter] removeObserver:self name:AVCaptureDeviceSubjectAreaDidChangeNotification object:[[self videoDeviceInput] device]];
        [[NSNotificationCenter defaultCenter] removeObserver:[self runtimeErrorHandlingObserver]];
        
        [self removeObserver:self forKeyPath:@"sessionRunningAndDeviceAuthorized" context:SessionRunningAndDeviceAuthorizedContext];
        [self removeObserver:self forKeyPath:@"stillImageOutput.capturingStillImage" context:CapturingStillImageContext];
        [self removeObserver:self forKeyPath:@"movieFileOutput.recording" context:RecordingContext];
    });
}

#pragma mark - Status bar

- (BOOL)prefersStatusBarHidden {
    return YES;
}

- (BOOL)shouldAutorotate {
    // Disable autorotation of the interface when recording is in progress.
    return YES;
    return ![self lockInterfaceRotation];
}

- (NSUInteger)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskPortrait;
    // return UIInterfaceOrientationMaskAll;
}

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {
    [[(AVCaptureVideoPreviewLayer *)[[self previewView] layer] connection] setVideoOrientation:(AVCaptureVideoOrientation)toInterfaceOrientation];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if (context == CapturingStillImageContext)
    {
        BOOL isCapturingStillImage = [change[NSKeyValueChangeNewKey] boolValue];
        
        if (isCapturingStillImage)
        {
            [self runStillImageCaptureAnimation];
        }
    }
    else if (context == RecordingContext)
    {
        BOOL isRecording = [change[NSKeyValueChangeNewKey] boolValue];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (isRecording)
            {
                // [[self cameraButton] setEnabled:NO];
                // [[self recordButton] setTitle:NSLocalizedString(@"Stop", @"Recording button stop title") forState:UIControlStateNormal];
                // [[self recordButton] setEnabled:YES];
            }
            else
            {
                // [[self cameraButton] setEnabled:YES];
                // [[self recordButton] setTitle:NSLocalizedString(@"Record", @"Recording button record title") forState:UIControlStateNormal];
                // [[self recordButton] setEnabled:YES];
            }
        });
    }
    else if (context == SessionRunningAndDeviceAuthorizedContext)
    {
        BOOL isRunning = [change[NSKeyValueChangeNewKey] boolValue];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (isRunning)
            {
                // [[self cameraButton] setEnabled:YES];
                // [[self recordButton] setEnabled:YES];
                // [[self stillButton] setEnabled:YES];
            }
            else
            {
                // [[self cameraButton] setEnabled:NO];
                // [[self recordButton] setEnabled:NO];
                // [[self stillButton] setEnabled:NO];
            }
        });
    }
    else
    {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

#pragma mark Actions

- (IBAction)toggleMovieRecording:(id)sender
{
    // [[self recordButton] setEnabled:NO];
    
    dispatch_async([self sessionQueue], ^{
        if (![[self movieFileOutput] isRecording])
        {
            [self setLockInterfaceRotation:YES];
            
            if ([[UIDevice currentDevice] isMultitaskingSupported])
            {
                // Setup background task. This is needed because the captureOutput:didFinishRecordingToOutputFileAtURL: callback is not received until AVCam returns to the foreground unless you request background execution time. This also ensures that there will be time to write the file to the assets library when AVCam is backgrounded. To conclude this background execution, -endBackgroundTask is called in -recorder:recordingDidFinishToOutputFileURL:error: after the recorded file has been saved.
                [self setBackgroundRecordingID:[[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:nil]];
            }
            
            // Update the orientation on the movie file output video connection before starting recording.
            [[[self movieFileOutput] connectionWithMediaType:AVMediaTypeVideo] setVideoOrientation:[[(AVCaptureVideoPreviewLayer *)[[self previewView] layer] connection] videoOrientation]];
            
            // Turning OFF flash for video recording
            [DMImagePicker setFlashMode:AVCaptureFlashModeOff forDevice:[[self videoDeviceInput] device]];
            
            // Start recording to a temporary file.
            NSString *outputFilePath = [NSTemporaryDirectory() stringByAppendingPathComponent:[@"movie" stringByAppendingPathExtension:@"mov"]];
            [[self movieFileOutput] startRecordingToOutputFileURL:[NSURL fileURLWithPath:outputFilePath] recordingDelegate:self];
        }
        else
        {
            [[self movieFileOutput] stopRecording];
        }
    });
}

- (IBAction)changeCamera:(id)sender {
    // [[self cameraButton] setEnabled:NO];
    // [[self recordButton] setEnabled:NO];
    // [[self stillButton] setEnabled:NO];
    
    dispatch_async([self sessionQueue], ^{
        AVCaptureDevice *currentVideoDevice = [[self videoDeviceInput] device];
        AVCaptureDevicePosition preferredPosition = AVCaptureDevicePositionUnspecified;
        AVCaptureDevicePosition currentPosition = [currentVideoDevice position];
        
        switch (currentPosition)
        {
            case AVCaptureDevicePositionUnspecified:
                preferredPosition = AVCaptureDevicePositionBack;
                break;
            case AVCaptureDevicePositionBack:
                preferredPosition = AVCaptureDevicePositionFront;
                break;
            case AVCaptureDevicePositionFront:
                preferredPosition = AVCaptureDevicePositionBack;
                break;
        }
        
        AVCaptureDevice *videoDevice = [DMImagePicker deviceWithMediaType:AVMediaTypeVideo preferringPosition:preferredPosition];
        AVCaptureDeviceInput *videoDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:videoDevice error:nil];
        
        [[self session] beginConfiguration];
        
        [[self session] removeInput:[self videoDeviceInput]];
        if ([[self session] canAddInput:videoDeviceInput])
        {
            [[NSNotificationCenter defaultCenter] removeObserver:self name:AVCaptureDeviceSubjectAreaDidChangeNotification object:currentVideoDevice];
            
            [DMImagePicker setFlashMode:AVCaptureFlashModeAuto forDevice:videoDevice];
            [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(subjectAreaDidChange:) name:AVCaptureDeviceSubjectAreaDidChangeNotification object:videoDevice];
            
            [[self session] addInput:videoDeviceInput];
            [self setVideoDeviceInput:videoDeviceInput];
        }
        else
        {
            [[self session] addInput:[self videoDeviceInput]];
        }
        
        [[self session] commitConfiguration];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            // [[self cameraButton] setEnabled:YES];
            // [[self recordButton] setEnabled:YES];
            // [[self stillButton] setEnabled:YES];
        });
    });
}

- (IBAction)snapStillImage:(id)sender {
    // weak self
    __weak typeof (self) weakSelf = self;
    
    dispatch_async([self sessionQueue], ^{
        // Update the orientation on the still image output video connection before capturing.
        // UIDeviceOrientation orientation = [UIDevice currentDevice].orientation;
        UIDeviceOrientation orientation = (UIDeviceOrientation) self.interfaceOrientation;
        
        // [[[self stillImageOutput] connectionWithMediaType:AVMediaTypeVideo] setVideoOrientation:[[(AVCaptureVideoPreviewLayer *)[[self previewView] layer] connection] videoOrientation]];
        [[[self stillImageOutput] connectionWithMediaType:AVMediaTypeVideo] setVideoOrientation:(AVCaptureVideoOrientation)orientation];
        
        // Flash set to Auto for Still Capture
        [DMImagePicker setFlashMode:AVCaptureFlashModeAuto forDevice:[[self videoDeviceInput] device]];
        
        DMImagePicker *strongSelf = weakSelf;
        
        // Capture a still image.
        [[self stillImageOutput] captureStillImageAsynchronouslyFromConnection:[[self stillImageOutput] connectionWithMediaType:AVMediaTypeVideo] completionHandler:^(CMSampleBufferRef imageDataSampleBuffer, NSError *error) {
            
            if (imageDataSampleBuffer) {
                
                NSData *imageData = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:imageDataSampleBuffer];
                UIImage *image = [[UIImage alloc] initWithData:imageData];
                UIImage *rotadedImage = DMImagePickerImageRotate(image);
                
                [strongSelf afterSnapStillImage:rotadedImage];
            }
        }];
    });
}

- (void)afterSnapStillImage:(UIImage *)image {
    // weak self
    __weak typeof (self) weakSelf = self;
    
    DMImageEditViewController *controller = [[DMImageEditViewController alloc] init];
    controller.originalImage = image;
    controller.cancelBlock = ^() {
        [weakSelf dismissViewControllerAnimated:YES completion:nil];
    };
    controller.doneBlock = ^(UIImage *image) {
        [weakSelf afterEditingImage:image];
    };
    
    [self presentViewController:controller animated:NO completion:nil];
}

- (void) afterEditingImage:(UIImage *)image {
    if (self.delegate == nil) return;

    if (![self.delegate respondsToSelector:@selector(dmImagePicker:takeImage:)]) return;

    [self.delegate dmImagePicker:self takeImage:image];
}

- (IBAction)focusAndExposeTap:(UIGestureRecognizer *)gestureRecognizer {
    CGPoint devicePoint = [(AVCaptureVideoPreviewLayer *)[[self previewView] layer] captureDevicePointOfInterestForPoint:[gestureRecognizer locationInView:[gestureRecognizer view]]];
    [self focusWithMode:AVCaptureFocusModeAutoFocus exposeWithMode:AVCaptureExposureModeAutoExpose atDevicePoint:devicePoint monitorSubjectAreaChange:YES];
}

- (void)subjectAreaDidChange:(NSNotification *)notification {
    CGPoint devicePoint = CGPointMake(.5, .5);
    [self focusWithMode:AVCaptureFocusModeContinuousAutoFocus exposeWithMode:AVCaptureExposureModeContinuousAutoExposure atDevicePoint:devicePoint monitorSubjectAreaChange:NO];
}

- (IBAction)cancelAction:(UIButton*)sender {
    if (self.delegate == nil) return;
    
    if (![self.delegate respondsToSelector:@selector(dmImagePickerCancel:)]) return;
    
    [self.delegate dmImagePickerCancel:self];
}

#pragma mark File Output Delegate

- (void)captureOutput:(AVCaptureFileOutput *)captureOutput didFinishRecordingToOutputFileAtURL:(NSURL *)outputFileURL fromConnections:(NSArray *)connections error:(NSError *)error {
    if (error)
        NSLog(@"%@", error);
    
    [self setLockInterfaceRotation:NO];
    
    // Note the backgroundRecordingID for use in the ALAssetsLibrary completion handler to end the background task associated with this recording. This allows a new recording to be started, associated with a new UIBackgroundTaskIdentifier, once the movie file output's -isRecording is back to NO — which happens sometime after this method returns.
    UIBackgroundTaskIdentifier backgroundRecordingID = [self backgroundRecordingID];
    [self setBackgroundRecordingID:UIBackgroundTaskInvalid];
    
    if (self.delegate == nil) return;
    
    if (![self.delegate respondsToSelector:@selector(dmImagePicker:takeVideo:)]) return;
    
    [self.delegate dmImagePicker:self takeVideo:outputFileURL];
    
    if (backgroundRecordingID != UIBackgroundTaskInvalid) {
        [[UIApplication sharedApplication] endBackgroundTask:backgroundRecordingID];
    }
    
//    [[[ALAssetsLibrary alloc] init] writeVideoAtPathToSavedPhotosAlbum:outputFileURL completionBlock:^(NSURL *assetURL, NSError *error) {
//        if (error)
//            NSLog(@"%@", error);
//        
//        [[NSFileManager defaultManager] removeItemAtURL:outputFileURL error:nil];
//        
//        if (backgroundRecordingID != UIBackgroundTaskInvalid)
//            [[UIApplication sharedApplication] endBackgroundTask:backgroundRecordingID];
//    }];
}

#pragma mark Device Configuration

- (void)focusWithMode:(AVCaptureFocusMode)focusMode exposeWithMode:(AVCaptureExposureMode)exposureMode atDevicePoint:(CGPoint)point monitorSubjectAreaChange:(BOOL)monitorSubjectAreaChange {
    dispatch_async([self sessionQueue], ^{
        AVCaptureDevice *device = [[self videoDeviceInput] device];
        NSError *error = nil;
        if ([device lockForConfiguration:&error])
        {
            if ([device isFocusPointOfInterestSupported] && [device isFocusModeSupported:focusMode])
            {
                [device setFocusMode:focusMode];
                [device setFocusPointOfInterest:point];
            }
            if ([device isExposurePointOfInterestSupported] && [device isExposureModeSupported:exposureMode])
            {
                [device setExposureMode:exposureMode];
                [device setExposurePointOfInterest:point];
            }
            [device setSubjectAreaChangeMonitoringEnabled:monitorSubjectAreaChange];
            [device unlockForConfiguration];
        }
        else
        {
            NSLog(@"%@", error);
        }
    });
}

+ (void)setFlashMode:(AVCaptureFlashMode)flashMode forDevice:(AVCaptureDevice *)device {
    if ([device hasFlash] && [device isFlashModeSupported:flashMode])
    {
        NSError *error = nil;
        if ([device lockForConfiguration:&error])
        {
            [device setFlashMode:flashMode];
            [device unlockForConfiguration];
        }
        else
        {
            NSLog(@"%@", error);
        }
    }
}

+ (AVCaptureDevice *)deviceWithMediaType:(NSString *)mediaType preferringPosition:(AVCaptureDevicePosition)position {
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:mediaType];
    AVCaptureDevice *captureDevice = [devices firstObject];
    
    for (AVCaptureDevice *device in devices)
    {
        if ([device position] == position)
        {
            captureDevice = device;
            break;
        }
    }
    
    return captureDevice;
}


#pragma mark UI

- (void)runStillImageCaptureAnimation {
    dispatch_async(dispatch_get_main_queue(), ^{
        [[[self previewView] layer] setOpacity:0.0];
        [UIView animateWithDuration:.25 animations:^{
            [[[self previewView] layer] setOpacity:1.0];
        }];
    });
}

- (void)checkDeviceAuthorizationStatus {
    NSString *mediaType = AVMediaTypeVideo;
    
    [AVCaptureDevice requestAccessForMediaType:mediaType completionHandler:^(BOOL granted) {
        if (granted) {
            //Granted access to mediaType
            [self setDeviceAuthorized:YES];
        } else {
            
            //Not granted access to mediaType
            dispatch_async(dispatch_get_main_queue(), ^{
                [[[UIAlertView alloc] initWithTitle:@"Warning!"
                                            message:@"App doesn't have permission to use Camera, please change privacy settings"
                                           delegate:self
                                  cancelButtonTitle:@"OK"
                                  otherButtonTitles:nil] show];
                [self setDeviceAuthorized:NO];
            });
        }
    }];
}


@end

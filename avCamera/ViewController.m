//
//  ViewController.m
//  avCamera
//
//  Created by Tong Liu on 08/09/2019.
//  Copyright © 2019 Tong Liu. All rights reserved.
//

#import "ViewController.h"
#import "CameraFocusSquare.h"

@interface ViewController ()
@property (weak, nonatomic) IBOutlet UIView *previewView;
@property (weak, nonatomic) IBOutlet UIImageView *captureImageView;

@property (nonatomic) AVCaptureSession *captureSession;
@property (nonatomic) AVCapturePhotoOutput *stillImageOutput;
@property (nonatomic) AVCaptureVideoPreviewLayer *videoPreviewLayer;
@property (nonatomic) AVCaptureDevice *acd;
@property (nonatomic) CameraFocusSquare *focusSquare;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    self.captureSession = [AVCaptureSession new];
    self.captureSession.sessionPreset = AVCaptureSessionPresetPhoto;
    
    AVCaptureDevice *backCamera = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
//    [backCamera lockForConfiguration];
//    backCamera.focusMode = AVCaptureFocusModeContinuousAutoFocus;
    
    NSError* err = nil;
    BOOL lockAcquired = [backCamera lockForConfiguration:&err];
    
    if (!lockAcquired) {
        // log err and handle...
    } else {
        // flip on the flash mode
        backCamera.focusMode = AVCaptureFocusModeContinuousAutoFocus;
        [backCamera unlockForConfiguration];
    }
    
    
    if (!backCamera) {
        NSLog(@"Unable to access back camera!");
        return;
    }
    
    NSError *error;
    AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:backCamera
                                                                        error:&error];
    if (!error) {
        //Step 9
    }
    else {
        NSLog(@"Error Unable to initialize back camera: %@", error.localizedDescription);
    }
    
    self.stillImageOutput = [AVCapturePhotoOutput new];
    
    if ([self.captureSession canAddInput:input] && [self.captureSession canAddOutput:self.stillImageOutput]) {
        
        [self.captureSession addInput:input];
        [self.captureSession addOutput:self.stillImageOutput];
        [self setupLivePreview];
    }
    
    
    UITapGestureRecognizer *shortTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTapToFocus:)];
    shortTap.numberOfTapsRequired=1;
    shortTap.numberOfTouchesRequired=1;
    [self.previewView addGestureRecognizer:shortTap];
    
    UIPinchGestureRecognizer *shortPinch = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(handlePinchToZoomRecognizer:)];
    [self.previewView addGestureRecognizer:shortPinch];
    // Setup your camera here...
    
    self.acd = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
}

-(void) handlePinchToZoomRecognizer:(UIPinchGestureRecognizer*)pinchRecognizer {
    const CGFloat pinchVelocityDividerFactor = 30.0f;
    
    if (pinchRecognizer.state == UIGestureRecognizerStateChanged) {
        NSError *error = nil;
        AVCaptureDevice *videoDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
        if ([videoDevice lockForConfiguration:&error]) {
            CGFloat desiredZoomFactor = self.acd.videoZoomFactor + atan2f(pinchRecognizer.velocity, pinchVelocityDividerFactor);
            // Check if desiredZoomFactor fits required range from 1.0 to activeFormat.videoMaxZoomFactor
            self.acd.videoZoomFactor = MAX(1.0, MIN(desiredZoomFactor, self.acd.activeFormat.videoMaxZoomFactor));
            [videoDevice unlockForConfiguration];
        } else {
            NSLog(@"error: failed to lock device for pintch-zoom configuration %@", error);
        }
    }
    
}

- (void)handleTapToFocus:(UITapGestureRecognizer *)tapGesture
{
   
    if (tapGesture.state == UIGestureRecognizerStateEnded)
    {
        CGPoint thisFocusPoint = [tapGesture locationInView:self.previewView];
        CGPoint focusPoint = [self.videoPreviewLayer captureDevicePointOfInterestForPoint:thisFocusPoint];

        if (!self.focusSquare) {
            self.focusSquare = [[CameraFocusSquare alloc] initWithTouchPoint:thisFocusPoint];
            [self.previewView addSubview:self.focusSquare];
            [self.focusSquare setNeedsDisplay];
        }
        else {
            [self.focusSquare updatePoint:thisFocusPoint];
        }
        [self.focusSquare animateFocusingAction];
        
        
        
        if ([self.acd isFocusModeSupported:AVCaptureFocusModeAutoFocus] && [self.acd isFocusPointOfInterestSupported])
        {
            if ([self.acd lockForConfiguration:nil])
            {
                [self.acd setFocusMode:AVCaptureFocusModeAutoFocus];
                [self.acd setFocusPointOfInterest:focusPoint];

                
                 if ([self.acd isExposureModeSupported:AVCaptureExposureModeAutoExpose] && [self.acd isExposurePointOfInterestSupported])
                 {
                     [self.acd setExposureMode:AVCaptureExposureModeAutoExpose];
                     [self.acd setExposurePointOfInterest:focusPoint]; //seems useless	
                 }
                
                [self.acd unlockForConfiguration];
            }
        }
    }
}

- (void)setupLivePreview {
    
    self.videoPreviewLayer = [AVCaptureVideoPreviewLayer layerWithSession:self.captureSession];
    
//    self.captureSession focus
    
    if (self.videoPreviewLayer) {
        
        self.videoPreviewLayer.videoGravity = AVLayerVideoGravityResizeAspect;
        self.videoPreviewLayer.connection.videoOrientation = AVCaptureVideoOrientationPortrait;
        [self.previewView.layer addSublayer:self.videoPreviewLayer];
        
        //Step12
        dispatch_queue_t globalQueue =  dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0);
        dispatch_async(globalQueue, ^{
            [self.captureSession startRunning];
            //Step 13
            dispatch_async(dispatch_get_main_queue(), ^{
                self.videoPreviewLayer.frame = self.previewView.bounds;
            });
        });
    }
}

- (IBAction)didTakePhoto:(id)sender {
    AVCapturePhotoSettings *settings = [AVCapturePhotoSettings photoSettingsWithFormat:@{AVVideoCodecKey: AVVideoCodecTypeJPEG}];
    
    [self.stillImageOutput capturePhotoWithSettings:settings delegate:self];
}

- (void)captureOutput:(AVCapturePhotoOutput *)output didFinishProcessingPhoto:(AVCapturePhoto *)photo error:(nullable NSError *)error {
    
    NSData *imageData = photo.fileDataRepresentation;
    if (imageData) {
        UIImage *image = [UIImage imageWithData:imageData];
        // Add the image to captureImageView here...
        self.captureImageView.image = image;
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self.captureSession stopRunning];
}

@end

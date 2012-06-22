//
//  ViewController.m
//  RealTimeEdigeCamera
//
//  Created by kazuki_tanaka on 12/03/15.
//  Copyright (c) 2012年 __MyCompanyName__. All rights reserved.
//

#import "ViewController.h"

@interface ViewController ()

@end

@implementation ViewController

#pragma mark - Orignal Method
- (void)setupAVCapture
{
    NSLog(@"========== setupAVCapture start ==========");
    
    NSError *error = nil;
    
    session = [[AVCaptureSession alloc] init];
    session.sessionPreset= AVCaptureSessionPresetMedium;
    
    AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    
    AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:device error:&error];
    [session addInput:input];
    
    AVCaptureVideoDataOutput *output = [[[AVCaptureVideoDataOutput alloc] init] autorelease];
    [session addOutput:output];
    
    [session commitConfiguration];
    
    dispatch_queue_t queue = dispatch_queue_create("myQueue", DISPATCH_QUEUE_SERIAL);
    [output setAlwaysDiscardsLateVideoFrames:YES];
    [output setSampleBufferDelegate:self queue:queue];
    
    dispatch_release(queue);
    
    output.videoSettings = [NSDictionary dictionaryWithObject:
                            [NSNumber numberWithInt:kCVPixelFormatType_32BGRA] 
                                                       forKey:(id)kCVPixelBufferPixelFormatTypeKey];
    
    customLayer = [CALayer layer];
    customLayer.frame = previewImageView.bounds;
    customLayer.transform = CATransform3DRotate(CATransform3DIdentity, M_PI/2.0f, 0, 0, 1);
    customLayer.contentsGravity = kCAGravityResizeAspectFill;
    [previewImageView.layer addSublayer:customLayer];
    
//    previewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:session];
//    [previewLayer setBackgroundColor:[[UIColor blackColor] CGColor]];
//    [previewLayer setVideoGravity:AVLayerVideoGravityResizeAspect];
//    [previewImageView.layer addSublayer:previewLayer];
    
//    CALayer *rootLayer = [previewImageView layer];
//    [rootLayer setMasksToBounds:YES];
//    [previewLayer setFrame:[rootLayer bounds]];
//    [rootLayer addSublayer:previewLayer];

    NSLog(@"========== setupAVCapture end ==========");
    
    if (!session.running) {
        [session startRunning];
    }
}

- (IplImage *)convertToIplImageFromSampleBuffer:(CMSampleBufferRef)sampleBuffer 
{
    IplImage *iplimage = 0;
    if (sampleBuffer) {
        CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
        CVPixelBufferLockBaseAddress(imageBuffer, 0);
        
        // get information of the image in the buffer
        uint8_t *bufferBaseAddress = (uint8_t *)CVPixelBufferGetBaseAddressOfPlane(imageBuffer, 0);
        size_t bufferWidth = CVPixelBufferGetWidth(imageBuffer);
        size_t bufferHeight = CVPixelBufferGetHeight(imageBuffer);
        
        // create IplImage
        if (bufferBaseAddress) {
            iplimage = cvCreateImage(cvSize(bufferWidth, bufferHeight), IPL_DEPTH_8U, 4);
            iplimage->imageData = (char*)bufferBaseAddress;
        }
        
        // release memory
        CVPixelBufferUnlockBaseAddress(imageBuffer, 0);
    }
    
    
    return iplimage;
}

- (CGImageRef)convertToCGImageFromIplImage:(IplImage *)image
{
    NSLog(@"========== convertToCGImageFromIplImage start ==========");
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    
    NSData *data = [NSData dataWithBytes:image->imageData length:image->imageSize];
    
    CGDataProviderRef provider = CGDataProviderCreateWithCFData((CFDataRef)data);
    
    CGImageRef cgImage = CGImageCreate(image->width,
                                       image->height,
                                       image->depth,
                                       image->depth * image->nChannels,
                                       image->widthStep,
                                       colorSpace,
                                       kCGImageAlphaNone | kCGBitmapByteOrderDefault,
                                       provider,
                                       NULL,
                                       false,
                                       kCGRenderingIntentDefault);
    
    NSLog(@"========== convertToCGImageFromIplImage end ==========");
    
    return cgImage;
}

- (CGImageRef)convertEdgeFilter:(IplImage *)srcImage
{
    NSLog(@"========== convertEdgeFilter start ==========");
    
    IplImage *grayScaleImage = cvCreateImage(cvGetSize(srcImage), IPL_DEPTH_8U, 1);
    
    cvCvtColor(srcImage, grayScaleImage, CV_BGR2GRAY);
    
    IplImage *destImage = cvCreateImage(cvGetSize(grayScaleImage), IPL_DEPTH_8U, 1);
    
    int minThreshold = 50;
    
    cvCanny(grayScaleImage, destImage, minThreshold, 200, 3);
    
    IplImage *colorImage = cvCreateImage(cvGetSize(srcImage), IPL_DEPTH_8U, 3);
    
    cvCvtColor(destImage, colorImage, CV_GRAY2BGR);
    
    CGImageRef effectedImage = [self convertToCGImageFromIplImage:colorImage];
    
    cvReleaseImage(&srcImage);
    cvReleaseImage(&grayScaleImage);
    cvReleaseImage(&destImage);
    cvReleaseImage(&colorImage);
    
     NSLog(@"========== convertEdgeFilter end ==========");
    
    return effectedImage;
}

#pragma mark - IBAction
- (IBAction)takePhotoAction:(id)sender
{
     NSLog(@"========== takePhotoAction start ==========");
    
    UIGraphicsBeginImageContext(customLayer.bounds.size);
    [customLayer renderInContext:UIGraphicsGetCurrentContext()];
    UIImage* image = UIGraphicsGetImageFromCurrentImageContext();
    UIImage *displayIamge = [UIImage imageWithCGImage:image.CGImage 
                                                scale:1.0f 
                                          orientation:UIImageOrientationRight];
    UIGraphicsEndImageContext();
    UIImageWriteToSavedPhotosAlbum(displayIamge, self, nil, nil);
    
    //UIImageWriteToSavedPhotosAlbum(previewImageView.image, self, nil, nil);
    
    NSLog(@"========== takePhotoAction end ==========");
}

#pragma mark - AVCaptureVideoDataOutputSampleBufferDelegate
- (void)captureOutput:(AVCaptureOutput *)captureOutput 
didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer 
       fromConnection:(AVCaptureConnection *)connection
{
    NSLog(@"========== captureOutput start ==========");
    
    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
    
    IplImage *inImage = [self convertToIplImageFromSampleBuffer:sampleBuffer];
    
    CGImageRef filteredImage = [self convertEdgeFilter:inImage];
    
//    UIImage *displayIamge = [UIImage imageWithCGImage:filteredImage scale:1.0f orientation:UIImageOrientationRight];

    [customLayer performSelectorOnMainThread:@selector(setContents:) 
                                       withObject:(id)filteredImage 
                                    waitUntilDone:YES];
    
//    dispatch_async(dispatch_get_main_queue(), ^(void) {
//        
//        cpreviewLayer.contents = (id)filteredImage;
//        //[previewImageView setImage:displayIamge];
//    });
    
    CGImageRelease(filteredImage);
    //CGImageRelease(inImage);

    [pool release];
    
    NSLog(@"========== captureOutput start ==========");
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    
    NSLog(@"========== viewDidLoad start ==========");
    
    [self setupAVCapture];
    
    NSLog(@"========== viewDidLoad end ============");
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation == UIInterfaceOrientationPortraitUpsideDown);
}

#pragma mark - dealloc
- (void)dealloc
{
    [session release]; session = nil;
    //[previewLayer release]; previewLayer = nil;
    
    [previewImageView release]; previewImageView = nil;
    
    [super dealloc];
}

@end

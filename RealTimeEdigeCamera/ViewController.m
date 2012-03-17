//
//  ViewController.m
//  RealTimeEdigeCamera
//
//  Created by kazuki_tanaka on 12/03/15.
//  Copyright (c) 2012年 __MyCompanyName__. All rights reserved.
//

#import "ViewController.h"

@interface ViewController ()

- (void)setupAVCapture;
- (IplImage *)convertToIplImageFromCGImage:(CGImageRef)image;
- (CGImageRef)convertToCGImageFromIplImage:(IplImage *)image;
- (CGImageRef)convertToCGImageFromSampleBuffer:(CMSampleBufferRef)sampleBuffer;
- (CGImageRef)convertEdgeFilter:(CGImageRef)inImage;
- (IBAction)takePhotoAction:(id)sender;
- (void)captureOutput:(AVCaptureOutput *)captureOutput 
didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer 
       fromConnection:(AVCaptureConnection *)connection;
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
    
    dispatch_queue_t queue = dispatch_queue_create("myQueue", NULL);
    [output setAlwaysDiscardsLateVideoFrames:YES];
    [output setSampleBufferDelegate:self queue:queue];
    
    dispatch_release(queue);
    
    output.videoSettings = [NSDictionary dictionaryWithObject:
                            [NSNumber numberWithInt:kCVPixelFormatType_32BGRA] 
                                                       forKey:(id)kCVPixelBufferPixelFormatTypeKey];
    /*
    previewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:session];
    [previewLayer setBackgroundColor:[[UIColor blackColor] CGColor]];
    [previewLayer setVideoGravity:AVLayerVideoGravityResizeAspect];
    
    CALayer *rootLayer = [previewImageView layer];
    [rootLayer setMasksToBounds:YES];
    [previewLayer setFrame:[rootLayer bounds]];
    [rootLayer addSublayer:previewLayer];
    */
    NSLog(@"========== setupAVCapture end ==========");
    
    if (!session.running) {
        [session startRunning];
    }
}

- (IplImage *)convertToIplImageFromCGImage:(CGImageRef)image
{
    NSLog(@"========== convertToIplImageFromCGImage start ==========");
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    
    IplImage *iplImage = cvCreateImage(cvSize(CGImageGetWidth(image), CGImageGetHeight(image)), IPL_DEPTH_8U, 4);
    
    CGContextRef contextRef = CGBitmapContextCreate(iplImage->imageData,
                                                    iplImage->width,
                                                    iplImage->height,
                                                    iplImage->depth,
                                                    iplImage->widthStep,
                                                    colorSpace,
                                                    kCGImageAlphaPremultipliedLast | kCGBitmapByteOrderDefault);
    
    CGContextDrawImage(contextRef, CGRectMake(0, 0, CGImageGetWidth(image), CGImageGetHeight(image)), image);
    
    CGContextRelease(contextRef);
    CGColorSpaceRelease(colorSpace);
    
    IplImage *ret = cvCreateImage(cvGetSize(iplImage), IPL_DEPTH_8U, 3);
    cvCvtColor(iplImage, ret, CV_RGBA2BGR);
    cvReleaseImage(&iplImage);
    
    NSLog(@"========== convertToIplImageFromCGImage end ==========");
    
    return ret;
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

- (CGImageRef)convertToCGImageFromSampleBuffer:(CMSampleBufferRef)sampleBuffer
{
    NSLog(@"========== convertToCGImageFromSampleBuffer start ==========");
    
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    
    CVPixelBufferLockBaseAddress(imageBuffer, 0);
    
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);
    size_t width = CVPixelBufferGetWidth(imageBuffer);
    size_t height = CVPixelBufferGetHeight(imageBuffer);
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    
    void *baseAddress = CVPixelBufferGetBaseAddress(imageBuffer);
    
    CGContextRef newContext = CGBitmapContextCreate(baseAddress,
                                                    width,
                                                    height,
                                                    8, 
                                                    bytesPerRow,
                                                    colorSpace,
                                                    kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
    
    CGImageRef cgImage = CGBitmapContextCreateImage(newContext);
    
    CGContextRelease(newContext);
    CGColorSpaceRelease(colorSpace);
    
    CVPixelBufferUnlockBaseAddress(imageBuffer, 0);
    
    [pool drain];
    
    NSLog(@"========== convertToCGImageFromSampleBuffer end ==========");
    
    return cgImage;
}

- (CGImageRef)convertEdgeFilter:(CGImageRef)inImage
{
    NSLog(@"========== convertEdgeFilter start ==========");
    
    IplImage *srcImage = [self convertToIplImageFromCGImage:inImage];
    
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
    
    UIImageWriteToSavedPhotosAlbum(previewImageView.image, self, nil, nil);
    
    NSLog(@"========== takePhotoAction end ==========");
}

#pragma mark - AVCaptureVideoDataOutputSampleBufferDelegate
- (void)captureOutput:(AVCaptureOutput *)captureOutput 
didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer 
       fromConnection:(AVCaptureConnection *)connection
{
    NSLog(@"========== captureOutput start ==========");
    
    CGImageRef inImage = [self convertToCGImageFromSampleBuffer:sampleBuffer];
    
    CGImageRef filteredImage = [self convertEdgeFilter:inImage];
    
    UIImage *displayIamge = [UIImage imageWithCGImage:filteredImage];
    
    CGImageRelease(filteredImage);
    CGImageRelease(inImage);

    /*
    [previewImageView performSelectorOnMainThread:@selector(setImage:) 
                                       withObject:displayIamge 
                                    waitUntilDone:YES];
     */
    
    dispatch_async(dispatch_get_main_queue(), ^(void) {
        
        [previewImageView setImage:displayIamge];
    });
    
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
    return (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
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

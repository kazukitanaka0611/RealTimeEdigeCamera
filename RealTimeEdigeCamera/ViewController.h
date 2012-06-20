//
//  ViewController.h
//  RealTimeEdigeCamera
//
//  Created by kazuki_tanaka on 12/03/15.
//  Copyright (c) 2012年 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>

#import <AVFoundation/AVFoundation.h>

#import <opencv2/imgproc/imgproc_c.h>

#import <QuartzCore/QuartzCore.h>

@interface ViewController : UIViewController
    <AVCaptureVideoDataOutputSampleBufferDelegate>
{
@private
    
    AVCaptureSession *session;
    AVCaptureVideoPreviewLayer *previewLayer;
    CALayer *cpreviewLayer;
    
    IBOutlet UIImageView *previewImageView;
}

- (IBAction)takePhotoAction:(id)sender;

@end

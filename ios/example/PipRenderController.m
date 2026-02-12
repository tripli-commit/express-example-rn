//
//  PipRenderController.m
//  example
//
//  Created by tripli on 2026/2/4.
//

#import "PipRenderController.h"
#import <AVKit/AVKit.h>
#import "CustomRenderUtil.h"

@import ZegoPrebuiltLog;

@interface PipRenderController() <AVPictureInPictureControllerDelegate>

@property (nonatomic, strong) AVPictureInPictureController *pipController;

@property (nonatomic, copy) NSString *pipStreamID;
@property (nonatomic, assign) ZegoViewMode pipViewMode;
@property (nonatomic, strong) UIView *pipRenderView;
@property (nonatomic, strong) AVSampleBufferDisplayLayer *pipRenderLayer;
@property (nonatomic, assign) int frameCount;

@end

@implementation PipRenderController

- (void)configPipModeRenderingWithStream:(NSString *)streamID rnPlayingView:(UIView *)rnPlayingView viewMode:(ZegoViewMode)viewMode
{
  [self closePipModeRendering];
  
  if (![AVPictureInPictureController isPictureInPictureSupported]) {
    return;
  }
  
  [[ZegoPrebuiltLog shared] write:@"[PipRenderController] configPipModeRenderingWithStream"];
  
  // PIP 配置
  NSError *error = nil;
  [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:&error];
  [[AVAudioSession sharedInstance] setActive:YES error:nil];
  if (error) {
      NSLog(@"PermissionFailed to set audio session, error:%@", error);
  }
  
  AVPictureInPictureVideoCallViewController *pipCallVC = [AVPictureInPictureVideoCallViewController new];
  pipCallVC.preferredContentSize = CGSizeMake(9, 16);
  
  AVPictureInPictureControllerContentSource *contentSource = [[AVPictureInPictureControllerContentSource alloc] initWithActiveVideoCallSourceView:rnPlayingView contentViewController:pipCallVC];
  
  self.pipController = [[AVPictureInPictureController alloc] initWithContentSource:contentSource];
  self.pipController.delegate = self;
  self.pipController.canStartPictureInPictureAutomaticallyFromInline = YES;
  [self.pipController setValue:[NSNumber numberWithInt:1] forKey:@"controlsStyle"];
  
  self.pipRenderView = [[UIView alloc] initWithFrame:CGRectZero];
  [pipCallVC.view addSubview:self.pipRenderView];
  
  self.pipRenderView.translatesAutoresizingMaskIntoConstraints = FALSE;
  [NSLayoutConstraint activateConstraints:@[
    [self.pipRenderView.leadingAnchor constraintEqualToAnchor:pipCallVC.view.leadingAnchor],
    [self.pipRenderView.trailingAnchor constraintEqualToAnchor:pipCallVC.view.trailingAnchor],
    [self.pipRenderView.topAnchor constraintEqualToAnchor:pipCallVC.view.topAnchor],
    [self.pipRenderView.bottomAnchor constraintEqualToAnchor:pipCallVC.view.bottomAnchor],
  ]];
  
  
  self.pipRenderLayer = [CustomRenderUtil addRenderLayerWithPlayingView:self.pipRenderView viewMode:viewMode];
  self.pipRenderLayer.frame = self.pipRenderView.bounds;
  self.frameCount = 0;
  [self.pipRenderView addObserver:self forKeyPath:@"bounds" options:NSKeyValueObservingOptionNew context:nil];
  
  self.pipViewMode = viewMode;
  self.pipStreamID = streamID;
}

- (void)stopPipModeRendering {
  [self.pipController stopPictureInPicture];
}

- (void)closePipModeRendering {
  [self.pipController stopPictureInPicture];
  
  if (self.pipRenderView) {
    [self.pipRenderView removeObserver:self forKeyPath:@"bounds"];
  }
  
  self.pipRenderLayer = NULL;
  self.pipRenderView = NULL;
  self.pipController = NULL;
}

- (void)enableMultiTaskForSDK:(BOOL)enable
{
  NSString *params = nil;
  if (enable) {
      params = @"{\"method\":\"liveroom.video.enable_ios_multitask\",\"params\":{\"enable\":true}}";
  } else {
      params = @"{\"method\":\"liveroom.video.enable_ios_multitask\",\"params\":{\"enable\":false}}";
  }
  
  [[ZegoExpressEngine sharedEngine] callExperimentalAPI:params];
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
  if (object == self.pipRenderView && [keyPath isEqualToString:@"bounds"]) {
    CGRect newBounds = [[change objectForKey:NSKeyValueChangeNewKey] CGRectValue];
    [[ZegoPrebuiltLog shared] write:[NSString stringWithFormat:@"[PipRenderController] layer frame changed: %@ -> %@", NSStringFromCGRect(self.pipRenderLayer.frame), NSStringFromCGRect(newBounds)]];
    self.pipRenderLayer.frame = newBounds;
  }
}

- (void)onRemoteVideoFrameCVPixelBuffer:(CVPixelBufferRef)buffer
                                  param:(ZegoVideoFrameParam *)param
                               streamID:(NSString *)streamID
{
  if (![streamID isEqualToString:self.pipStreamID]) {
    return;
  }
  
  AVSampleBufferDisplayLayer *destLayer = self.pipRenderLayer;
  if (destLayer == NULL) {
    return;
  }
  
  self.frameCount += 1;
  if (self.frameCount == 1) {
    [[ZegoPrebuiltLog shared] write:[NSString stringWithFormat:@"[PipRenderController] first layer frame, width:%.0zu, height:%.0zu", CVPixelBufferGetWidth(buffer), CVPixelBufferGetHeight(buffer)]];
  }
  if (self.frameCount <= 2) {
    return;
  }
  
  CMSampleBufferRef sampleBuffer = [CustomRenderUtil createSampleBuffer:buffer];
  if (sampleBuffer) {
    [destLayer enqueueSampleBuffer:sampleBuffer];
    if (destLayer.status == AVQueuedSampleBufferRenderingStatusFailed) {
      if (-11847 == destLayer.error.code) {
        [self.pipRenderLayer removeFromSuperlayer];
        
        [[ZegoPrebuiltLog shared] write:[NSString stringWithFormat:@"[PipRenderController] rebuildLayer, streamID:%@", streamID]];
        self.pipRenderLayer = [CustomRenderUtil addRenderLayerWithPlayingView:self.pipRenderView viewMode:self.pipViewMode];
        self.pipRenderLayer.frame = self.pipRenderView.bounds;
        self.frameCount = 0;
      }
    }
    CFRelease(sampleBuffer);
  }
}

#pragma mark - AVPictureInPictureControllerDelegate

- (void)pictureInPictureControllerWillStartPictureInPicture:(AVPictureInPictureController *)pictureInPictureController
{
  [[ZegoPrebuiltLog shared] write:@"[PipRenderController] pictureInPictureController willStart"];
  [self enableMultiTaskForSDK:TRUE];
}

- (void)pictureInPictureControllerDidStartPictureInPicture:(AVPictureInPictureController *)pictureInPictureController
{
  [[ZegoPrebuiltLog shared] write:@"[PipRenderController] pictureInPictureController didStart"];
}

- (void)pictureInPictureController:(AVPictureInPictureController *)pictureInPictureController failedToStartPictureInPictureWithError:(NSError *)error
{
  [[ZegoPrebuiltLog shared] write:[NSString stringWithFormat:@"[PipRenderController] pictureInPictureController failedToStart, error: %@", error]];
}

- (void)pictureInPictureControllerWillStopPictureInPicture:(AVPictureInPictureController *)pictureInPictureController
{
  [[ZegoPrebuiltLog shared] write:@"[PipRenderController] pictureInPictureController willStop"];
  [self enableMultiTaskForSDK:FALSE];
}

- (void)pictureInPictureControllerDidStopPictureInPicture:(AVPictureInPictureController *)pictureInPictureController
{
  [[ZegoPrebuiltLog shared] write:@"[PipRenderController] pictureInPictureController didStop"];
}

- (void)pictureInPictureController:(AVPictureInPictureController *)pictureInPictureController restoreUserInterfaceForPictureInPictureStopWithCompletionHandler:(void (^)(BOOL restored))completionHandler
{
  [[ZegoPrebuiltLog shared] write:@"[PipRenderController] pictureInPictureController restoreUserInterface"];
  completionHandler(YES);
}

@end

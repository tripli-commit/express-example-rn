//
//  CustomRenderDispatcher.m
//  example
//
//  Created by tripli on 2026/2/3.
//

#import "CustomRenderDispatcher.h"
#import "CustomRenderUtil.h"
#import "ControlManager.h"
#import "PlayingRenderController.h"

@import ZegoPrebuiltLog;

@interface CustomRenderDispatcher() <ZegoCustomVideoRenderHandler>

@property (nonatomic, assign) BOOL inBackground;
@property (nonatomic, assign) BOOL isCustomVideoRenderEnabled;

@end

@implementation CustomRenderDispatcher

- (instancetype)init {
  self = [super init];
  if (self) {
    [[ZegoPrebuiltLog shared] write:@"[CustomRenderDispatcher] init"];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleApplicationDidBecomeActive:)
                                                 name:UIApplicationDidBecomeActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleApplicationDidEnterBackground:)
                                                 name:UIApplicationDidEnterBackgroundNotification object:nil];
    
    [self enableCustomVideoRender];
  }
  return self;
}

#pragma mark - private

- (void)enableCustomVideoRender {
  if (NO == self.isCustomVideoRenderEnabled) {
    [[ZegoPrebuiltLog shared] write:[NSString stringWithFormat:@"[CustomRenderDispatcher] enableHardwareDecoder"]];
    [[ZegoExpressEngine sharedEngine] enableHardwareDecoder:YES];

    // 开始自定义渲染，在渲染回调中投递到不同 layer
    ZegoCustomVideoRenderConfig *renderConfig = [[ZegoCustomVideoRenderConfig alloc] init];
    renderConfig.bufferType = ZegoVideoBufferTypeCVPixelBuffer;
    renderConfig.frameFormatSeries = ZegoVideoFrameFormatSeriesRGB;

    [[ZegoPrebuiltLog shared] write:[NSString stringWithFormat:@"[CustomRenderDispatcher] enableCustomVideoRender"]];
    [[ZegoExpressEngine sharedEngine] enableCustomVideoRender:YES config:renderConfig];
    [[ZegoExpressEngine sharedEngine] setCustomVideoRenderHandler:self];
    
    self.isCustomVideoRenderEnabled = YES;
  }
}

- (void)handleApplicationDidBecomeActive:(NSNotification *)notify {
  NSLog(@"handleApplicationDidBecomeActive");
  self.inBackground = NO;
  [[ControlManager sharedInstance].pipRenderController stopPipModeRendering];
}
  
- (void)handleApplicationDidEnterBackground:(NSNotification *)notify {
  NSLog(@"handleApplicationDidEnterBackground");
  self.inBackground = YES;
}

#pragma mark - ZegoCustomVideoRenderHandler

- (void)onRemoteVideoFrameCVPixelBuffer:(CVPixelBufferRef)buffer
                                  param:(ZegoVideoFrameParam *)param
                               streamID:(NSString *)streamID
{
  id <ZegoCustomVideoRenderHandler> renderController = NULL;
  if (!self.inBackground) {
    renderController = [ControlManager sharedInstance].playingRenderController;
  } else {
    renderController = [ControlManager sharedInstance].pipRenderController;
  }
  
  [renderController onRemoteVideoFrameCVPixelBuffer:buffer
                                              param:param
                                           streamID:streamID];
}

- (void)onCapturedVideoFrameCVPixelBuffer:(CVPixelBufferRef)buffer
                                    param:(ZegoVideoFrameParam *)param
                                 flipMode:(ZegoVideoFlipMode)flipMode
                                  channel:(ZegoPublishChannel)channel
{
  PreviewRenderController *previewController = [ControlManager sharedInstance].previewRenderController;
  [previewController onCapturedVideoFrameCVPixelBuffer:buffer
                                                 param:param
                                              flipMode:flipMode
                                               channel:channel];
}

@end

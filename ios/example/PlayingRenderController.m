//
//  PlayingRenderController.m
//  example
//
//  Created by tripli on 2026/2/4.
//

#import "PlayingRenderController.h"
#import "CustomRenderUtil.h"
#import "ControlManager.h"

@import ZegoPrebuiltLog;

@interface PlayingRenderController()

@property (nonatomic, strong) NSMutableDictionary *renderViewDict;    // <streamID, view>
@property (nonatomic, strong) NSMutableDictionary *viewModeDict;      // <streamID, viewMode>
@property (nonatomic, strong) NSMutableDictionary *renderLayerDict;   // <streamID, layer>

@end

@implementation PlayingRenderController

- (instancetype)init {
  self = [super init];
  if (self) {
    [[ZegoPrebuiltLog shared] write:@"[PlayingRenderController] init"];
    
    _renderViewDict = [NSMutableDictionary dictionary];
    _viewModeDict = [NSMutableDictionary dictionary];
    _renderLayerDict = [NSMutableDictionary dictionary];
  }
  return self;
}

- (void)startPlayingStream:(NSString *)streamID rnPlayingView:(RCTView *)rnPlayingView viewMode:(ZegoViewMode)viewMode
{
  [[ZegoPrebuiltLog shared] write:[NSString stringWithFormat:@"[PlayingRenderController] startPlayingStream: %@, rnPlayingView: %lu", streamID, (unsigned long)rnPlayingView.hash]];
  
  [[ControlManager sharedInstance].customRenderDispatcher enableCustomVideoRender];
    
  // 为 rn view 添加用于自定义渲染的 layer，没找到就添加一个
  AVSampleBufferDisplayLayer *renderLayer = [CustomRenderUtil addRenderLayerWithPlayingView:rnPlayingView viewMode:viewMode];
  
  self.renderViewDict[streamID] = rnPlayingView;
  self.viewModeDict[streamID] = @(viewMode);
  self.renderLayerDict[streamID] = renderLayer;
    
  [[ZegoExpressEngine sharedEngine] startPlayingStream:streamID];
}

- (void)stopPlayingStream:(NSString *)streamID {
  [[ZegoExpressEngine sharedEngine] stopPlayingStream:streamID];

  self.renderViewDict[streamID] = NULL;
  self.viewModeDict[streamID] = NULL;
  self.renderLayerDict[streamID] = NULL;
}

- (void)onRemoteVideoFrameCVPixelBuffer:(CVPixelBufferRef)buffer
                                  param:(ZegoVideoFrameParam *)param
                               streamID:(NSString *)streamID
{
  AVSampleBufferDisplayLayer *destLayer = self.renderLayerDict[streamID];
  if (destLayer == NULL) {
    return;
  }

  CMSampleBufferRef sampleBuffer = [CustomRenderUtil createSampleBuffer:buffer];
  if (sampleBuffer) {
    [destLayer enqueueSampleBuffer:sampleBuffer];
    if (destLayer.status == AVQueuedSampleBufferRenderingStatusFailed) {
      if (-11847 == destLayer.error.code) {
        [destLayer removeFromSuperlayer];
        self.renderLayerDict[streamID] = nil;
        
        [[ZegoPrebuiltLog shared] write:[NSString stringWithFormat:@"[PlayingRenderController] rebuildLayer, streamID:%@", streamID]];
        RCTView *rnView = self.renderViewDict[streamID];
        destLayer = [CustomRenderUtil addRenderLayerWithPlayingView:rnView viewMode:[self.viewModeDict[streamID] intValue]];
        self.renderLayerDict[streamID] = destLayer;
      }
    }
    CFRelease(sampleBuffer);
  }
}

@end

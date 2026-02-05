//
//  PreviewRenderController.m
//  example
//
//  Created by tripli on 2026/2/4.
//

#import "PreviewRenderController.h"
#import "CustomRenderUtil.h"
#import "ControlManager.h"

@import ZegoPrebuiltLog;

@interface PreviewRenderController()

@property (nonatomic, assign) ZegoViewMode previewViewMode;
@property (nonatomic, strong) RCTView *rnPreviewView;
@property (nonatomic, strong) AVSampleBufferDisplayLayer *rnPreviewLayer;

@end

@implementation PreviewRenderController

- (void)startPreview:(RCTView *)rnPreviewView viewMode:(ZegoViewMode)viewMode {
  [[ZegoPrebuiltLog shared] write:[NSString stringWithFormat:@"[PreviewRenderController] startPreview, rnPreviewView: %lu", (unsigned long)rnPreviewView.hash]];
  
  [[ControlManager sharedInstance].customRenderDispatcher enableCustomVideoRender];
  
  self.previewViewMode = viewMode;
  self.rnPreviewView = rnPreviewView;
  
  // 为 rn view 添加用于自定义渲染的 layer，没找到就添加一个
  AVSampleBufferDisplayLayer *renderLayer = [CustomRenderUtil addRenderLayerWithPlayingView:rnPreviewView viewMode:viewMode];
  self.rnPreviewLayer = renderLayer;

  [[ZegoExpressEngine sharedEngine] startPreview];
}

- (void)stopPreview {
  [[ZegoExpressEngine sharedEngine] stopPreview];
  
  self.rnPreviewLayer = NULL;
  self.rnPreviewView = NULL;
}

- (void)onCapturedVideoFrameCVPixelBuffer:(CVPixelBufferRef)buffer
                                    param:(ZegoVideoFrameParam *)param
                                 flipMode:(ZegoVideoFlipMode)flipMode
                                  channel:(ZegoPublishChannel)channel
{
  if (self.rnPreviewLayer == NULL) {
    return;
  }
  
  CMSampleBufferRef sampleBuffer = [CustomRenderUtil createSampleBuffer:buffer];
  if (sampleBuffer) {
      [self.rnPreviewLayer enqueueSampleBuffer:sampleBuffer];
      if (self.rnPreviewLayer.status == AVQueuedSampleBufferRenderingStatusFailed) {
          if (-11847 == self.rnPreviewLayer.error.code) {
            [self.rnPreviewLayer removeFromSuperlayer];
            
            [[ZegoPrebuiltLog shared] write:@"[PreviewRenderController] rebuildLayer"];
            self.rnPreviewLayer = [CustomRenderUtil addRenderLayerWithPlayingView:self.rnPreviewView viewMode:self.previewViewMode];
          }
      }
      CFRelease(sampleBuffer);
  }

}

@end

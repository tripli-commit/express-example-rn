//
//  CustomRenderUtil.m
//  example
//
//  Created by tripli on 2026/2/3.
//

#import "CustomRenderUtil.h"

#define kKitDisplayLayerName   @"KitDisplayLayer"

@implementation CustomRenderUtil

+ (AVSampleBufferDisplayLayer *)addRenderLayerWithPlayingView:(UIView *)playingView viewMode:(ZegoViewMode)viewMode {
  AVSampleBufferDisplayLayer *foundLayer = NULL;
  for (CALayer *layer in playingView.layer.sublayers) {
      if ([layer.name isEqualToString:kKitDisplayLayerName] && [layer isKindOfClass:[AVSampleBufferDisplayLayer class]]) {
        foundLayer = (AVSampleBufferDisplayLayer *)layer;
        break;
      }
  }
  
  if (!foundLayer) {
    foundLayer = [self createAVSampleBufferDisplayLayerWithViewMode:viewMode];
    foundLayer.name = kKitDisplayLayerName;
    [playingView.layer addSublayer:foundLayer];
  }
  
  // 约定 rn 层每次调整 view 大小，都需要重新调用一次 startPlayingStream - addRenderLayer，借此调整 layer 的 frame
  foundLayer.frame = playingView.bounds;
  return foundLayer;
}

+ (AVSampleBufferDisplayLayer *)createAVSampleBufferDisplayLayerWithViewMode:(ZegoViewMode)viewMode {
  AVSampleBufferDisplayLayer *layer = [[AVSampleBufferDisplayLayer alloc] init];
  layer.opaque = YES;
  
  switch (viewMode) {
    case ZegoViewModeAspectFit:
      layer.videoGravity = AVLayerVideoGravityResizeAspect;
      break;
    case ZegoViewModeAspectFill:
      layer.videoGravity = AVLayerVideoGravityResizeAspectFill;
      break;
    case ZegoViewModeScaleToFill:
      layer.videoGravity = AVLayerVideoGravityResize;
      break;
    default:
      layer.videoGravity = AVLayerVideoGravityResizeAspect;
      break;
  }
  
  return layer;
}

+ (CMSampleBufferRef)createSampleBuffer:(CVPixelBufferRef)pixelBuffer {
    if (!pixelBuffer) {
        return NULL;
    }
    //不设置具体时间信息
    CMSampleTimingInfo timing = {kCMTimeInvalid, kCMTimeInvalid, kCMTimeInvalid};
    //获取视频信息
    CMVideoFormatDescriptionRef videoInfo = NULL;
    OSStatus result = CMVideoFormatDescriptionCreateForImageBuffer(NULL, pixelBuffer, &videoInfo);
    NSParameterAssert(result == 0 && videoInfo != NULL);
    
    CMSampleBufferRef sampleBuffer = NULL;
    result = CMSampleBufferCreateForImageBuffer(kCFAllocatorDefault, pixelBuffer, true, NULL, NULL, videoInfo, &timing, &sampleBuffer);
    NSParameterAssert(result == 0 && sampleBuffer != NULL);
    CFRelease(videoInfo);
    CFArrayRef attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, YES);
    CFMutableDictionaryRef dict = (CFMutableDictionaryRef)CFArrayGetValueAtIndex(attachments, 0);
    CFDictionarySetValue(dict, kCMSampleAttachmentKey_DisplayImmediately, kCFBooleanTrue);
    return sampleBuffer;
}

@end

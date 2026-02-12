#import "PipModule.h"

#import <React/RCTBridge.h>
#import <React/RCTUIManager.h>
#import <React/RCTView.h>

#import "CustomRenderDispatcher.h"
#import "ControlManager.h"

@import ZegoPrebuiltLog;

@implementation PipModule

@synthesize bridge = _bridge;

RCT_EXPORT_MODULE();

RCT_EXPORT_METHOD(notifyPagePipEnable:(BOOL)pipEnable pageName:(NSString *)pageName) {
  dispatch_async(dispatch_get_main_queue(), ^{
    [[ZegoPrebuiltLog shared] write:[NSString stringWithFormat:@"[PipModule] notifyPagePipEnable, pipEnable: %d, pageName: %@, do nothing", pipEnable, pageName]];
  });
}

RCT_EXPORT_METHOD(startPlayingStream:(NSDictionary *)map) {
  dispatch_async(dispatch_get_main_queue(), ^{
    NSString *streamID = map[@"streamID"];
    NSNumber *viewMode = map[@"viewMode"];
    
    NSNumber *reactTag = map[@"reactTag"];
    RCTView *rctView = (RCTView *)[self->_bridge.uiManager viewForReactTag: reactTag];
    
    [[ZegoPrebuiltLog shared] write:[NSString stringWithFormat:@"[PipModule] startPlayingStream: %@, reactTag: %@, viewMode: %@, rnPlayingView: %lu", streamID, reactTag, viewMode, (unsigned long)rctView.hash]];
    
    [[ControlManager sharedInstance].playingRenderController startPlayingStream:streamID rnPlayingView:rctView viewMode:viewMode.unsignedIntValue];
  });
}

RCT_EXPORT_METHOD(stopPlayingStream:(NSDictionary *)map) {
  dispatch_async(dispatch_get_main_queue(), ^{
    NSString *streamID = map[@"streamID"];
    
    [[ZegoPrebuiltLog shared] write:[NSString stringWithFormat:@"[PipModule] stopPlayingStream: %@", streamID]];
    
    [[ControlManager sharedInstance].playingRenderController stopPlayingStream:streamID];
  });
}

RCT_EXPORT_METHOD(startPreview:(NSDictionary *)map) {
  dispatch_async(dispatch_get_main_queue(), ^{
    NSNumber *viewMode = map[@"viewMode"];
    
    NSNumber *reactTag = map[@"reactTag"];
    RCTView *rctView = (RCTView *)[self->_bridge.uiManager viewForReactTag: reactTag];
    
    NSLog(@"[PipModule] startPreview, reactTag: %@, viewMode: %@, rnPlayingView: %lu", reactTag, viewMode, (unsigned long)rctView.hash);
    
    [[ControlManager sharedInstance].previewRenderController startPreview:rctView viewMode:viewMode.unsignedIntValue];
  });
}

RCT_EXPORT_METHOD(stopPreview) {
  dispatch_async(dispatch_get_main_queue(), ^{
    [[ControlManager sharedInstance].previewRenderController stopPreview];
  });
}

RCT_EXPORT_METHOD(configPipModeRendering:(NSDictionary *)map) {
  dispatch_async(dispatch_get_main_queue(), ^{
    NSNumber *viewMode = map[@"viewMode"];
    NSString *streamID = map[@"streamID"];
    
    NSNumber *reactTag = map[@"reactTag"];
    RCTView *rctView = NULL;
    if (reactTag != NULL && ![reactTag isKindOfClass:[NSNull class]]) {
      rctView = (RCTView *)[self->_bridge.uiManager viewForReactTag: reactTag];
    }
    
    [[ZegoPrebuiltLog shared] write:[NSString stringWithFormat:@"[PipModule] configPipModeRendering, stream: %@, rnPlayingView: %lu", streamID, (unsigned long)rctView.hash]];
    
    if (rctView != NULL) {
      [[ControlManager sharedInstance].pipRenderController configPipModeRenderingWithStream:streamID rnPlayingView:rctView viewMode:viewMode.unsignedIntValue];
    } else {
      [[ControlManager sharedInstance].pipRenderController closePipModeRendering];
    }
  });
}

RCT_EXPORT_METHOD(closePipModeRendering:(NSDictionary *)map) {
  dispatch_async(dispatch_get_main_queue(), ^{
    [[ControlManager sharedInstance].pipRenderController closePipModeRendering];
  });
}

RCT_EXPORT_METHOD(addListener:(NSString *)eventName) {
  
}

RCT_EXPORT_METHOD(removeListeners:(int)count) {
  
}

@end

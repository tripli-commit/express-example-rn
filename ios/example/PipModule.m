#import "PipModule.h"
#import "PipManager.h"

#import <React/RCTBridge.h>
#import <React/RCTUIManager.h>
#import <React/RCTView.h>

@implementation PipModule

@synthesize bridge = _bridge;

RCT_EXPORT_MODULE();

RCT_EXPORT_METHOD(notifyPagePipEnable:(BOOL)pipEnable pageName:(NSString *)pageName)
{
  dispatch_async(dispatch_get_main_queue(), ^{
    NSLog(@"[PipModule] notifyPagePipEnable, pipEnable: %d, pageName: %@", pipEnable, pageName);
    [[PipManager sharedInstance] notifyPagePipEnable:pipEnable pageName:pageName];
  });
}

RCT_EXPORT_METHOD(startPlayingStream:(NSDictionary *)map)
{
  dispatch_async(dispatch_get_main_queue(), ^{
    NSString *streamID = map[@"streamID"];
    NSNumber *reactTag = map[@"reactTag"];
    NSNumber *viewMode = map[@"viewMode"];
    
    RCTView *rctView = (RCTView *)[self->_bridge.uiManager viewForReactTag: reactTag];
    
    NSLog(@"[PipModule] startPlayingStream: %@, reactTag: %@, viewMode: %@, rnPlayingView: %@", streamID, reactTag, viewMode, rctView);
    [[PipManager sharedInstance] startPlayingStream:streamID rnPlayingView:rctView viewMode:viewMode.unsignedIntValue];
  });
}

RCT_EXPORT_METHOD(stopPlayingStream:(NSDictionary *)map)
{
  dispatch_async(dispatch_get_main_queue(), ^{
    NSString *streamID = map[@"streamID"];
    
    NSLog(@"[PipModule] stopPlayingStream: %@", streamID);
    
    [[PipManager sharedInstance] stopPlayingStream:streamID];
  });
}

RCT_EXPORT_METHOD(startPreview:(NSDictionary *)map)
{
  dispatch_async(dispatch_get_main_queue(), ^{
    NSNumber *reactTag = map[@"reactTag"];
    NSNumber *viewMode = map[@"viewMode"];
    
    RCTView *rctView = (RCTView *)[self->_bridge.uiManager viewForReactTag: reactTag];
    
    NSLog(@"[PipModule] startPreview, reactTag: %@, viewMode: %@, rnPlayingView: %@", reactTag, viewMode, rctView);
    [[PipManager sharedInstance] startPreview:rctView viewMode:viewMode.unsignedIntValue];
  });
}

RCT_EXPORT_METHOD(stopPreview) {
  [[PipManager sharedInstance] stopPreview];
}

RCT_EXPORT_METHOD(addListener:(NSString *)eventName) {
  
}

RCT_EXPORT_METHOD(removeListeners:(int)count) {
  
}

@end

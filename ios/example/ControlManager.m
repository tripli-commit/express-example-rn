//
//  ControlManager.m
//  example
//
//  Created by tripli on 2026/2/4.
//

#import "ControlManager.h"

static dispatch_once_t onceToken;
static id _instance;

@interface ControlManager()

@property (nonatomic, strong, readwrite) CustomRenderDispatcher *customRenderDispatcher;
@property (nonatomic, strong, readwrite) PlayingRenderController *playingRenderController;
@property (nonatomic, strong, readwrite) PreviewRenderController *previewRenderController;
@property (nonatomic, strong, readwrite) PipRenderController *pipRenderController;

@end

@implementation ControlManager

+ (instancetype)sharedInstance {
  dispatch_once(&onceToken, ^{
    _instance = [[self alloc] init];
  });
  return _instance;
}

- (nonnull CustomRenderDispatcher *)getCustomRenderDispatcher {
  if (_customRenderDispatcher == NULL) {
    self.customRenderDispatcher = [CustomRenderDispatcher new];
  }
  return _customRenderDispatcher;
}

- (nonnull PlayingRenderController *)getPlayingRenderController {
  if (_playingRenderController == NULL) {
    self.playingRenderController = [PlayingRenderController new];
  }
  return _playingRenderController;
}

- (nonnull PreviewRenderController *)getPreviewRenderController {
  if (_previewRenderController == NULL) {
    self.previewRenderController = [PreviewRenderController new];
  }
  return _previewRenderController;
}

- (nonnull PipRenderController *)getPipRenderController {
  if (_pipRenderController == NULL) {
    self.pipRenderController = [PipRenderController new];
  }
  return _pipRenderController;
}

@end

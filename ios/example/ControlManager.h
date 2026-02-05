//
//  ControlManager.h
//  example
//
//  Created by tripli on 2026/2/4.
//

#import <Foundation/Foundation.h>
#import "CustomRenderDispatcher.h"
#import "PlayingRenderController.h"
#import "PreviewRenderController.h"
#import "PipRenderController.h"

NS_ASSUME_NONNULL_BEGIN

@interface ControlManager : NSObject

@property (nonatomic, strong, readonly, getter=getCustomRenderDispatcher) CustomRenderDispatcher *customRenderDispatcher;
@property (nonatomic, strong, readonly, getter=getPlayingRenderController) PlayingRenderController *playingRenderController;
@property (nonatomic, strong, readonly, getter=getPreviewRenderController) PreviewRenderController *previewRenderController;
@property (nonatomic, strong, readonly, getter=getPipRenderController) PipRenderController *pipRenderController;

+ (instancetype)sharedInstance;

@end

NS_ASSUME_NONNULL_END

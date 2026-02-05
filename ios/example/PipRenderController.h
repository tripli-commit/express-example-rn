//
//  PipRenderController.h
//  example
//
//  Created by tripli on 2026/2/4.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@import ZegoExpressEngine;

NS_ASSUME_NONNULL_BEGIN

@interface PipRenderController : NSObject <ZegoCustomVideoRenderHandler>

- (void)configPipModeRenderingWithStream:(NSString *)streamID rnPlayingView:(UIView *)rnPlayingView viewMode:(ZegoViewMode)viewMode;

- (void)stopPipModeRendering;

- (void)closePipModeRendering;

@end

NS_ASSUME_NONNULL_END

//
//  PlayingRenderController.h
//  example
//
//  Created by tripli on 2026/2/4.
//

#import <Foundation/Foundation.h>
#import <React/RCTView.h>

@import ZegoExpressEngine;

NS_ASSUME_NONNULL_BEGIN

@interface PlayingRenderController : NSObject <ZegoCustomVideoRenderHandler>

- (void)startPlayingStream:(NSString *)streamID rnPlayingView:(RCTView *)rnPlayingView viewMode:(ZegoViewMode)viewMode;

- (void)stopPlayingStream:(NSString *)streamID;

@end

NS_ASSUME_NONNULL_END

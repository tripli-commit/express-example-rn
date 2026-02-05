//
//  PreviewRenderController.h
//  example
//
//  Created by tripli on 2026/2/4.
//

#import <Foundation/Foundation.h>
#import <React/RCTView.h>

@import ZegoExpressEngine;

NS_ASSUME_NONNULL_BEGIN

@interface PreviewRenderController : NSObject <ZegoCustomVideoRenderHandler>

- (void)startPreview:(RCTView *)rnPreviewView viewMode:(ZegoViewMode)viewMode;

- (void)stopPreview;

@end

NS_ASSUME_NONNULL_END

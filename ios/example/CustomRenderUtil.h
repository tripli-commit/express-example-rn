//
//  CustomRenderUtil.h
//  example
//
//  Created by tripli on 2026/2/3.
//

#import <Foundation/Foundation.h>

@import ZegoExpressEngine;

NS_ASSUME_NONNULL_BEGIN

@interface CustomRenderUtil : NSObject

+ (AVSampleBufferDisplayLayer *)addRenderLayerWithPlayingView:(UIView *)playingView viewMode:(ZegoViewMode)viewMode;

+ (CMSampleBufferRef)createSampleBuffer:(CVPixelBufferRef)pixelBuffer;

@end

NS_ASSUME_NONNULL_END

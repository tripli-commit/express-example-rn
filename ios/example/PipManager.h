
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <React/RCTView.h>

@import ZegoExpressEngine;

NS_ASSUME_NONNULL_BEGIN

@interface PipManager : NSObject

+ (instancetype)sharedInstance;

- (void)startPlayingStream:(NSString *)streamID rnPlayingView:(RCTView *)rnPlayingView viewMode:(ZegoViewMode)viewMode;
- (void)stopPlayingStream:(NSString *)streamID;

- (void)notifyPagePipEnable:(BOOL)pipEnable pageName:(NSString *)pageName;

@end

NS_ASSUME_NONNULL_END

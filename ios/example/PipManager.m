#import "PipManager.h"
#import <AVKit/AVKit.h>
#import "Masonry.h"
#import "KitRemoteView.h"

#define kKitDisplayLayerName   @"KitDisplayLayer"

static dispatch_once_t onceToken;
static id _instance;

API_AVAILABLE(ios(15.0))
@interface PipManager () <AVPictureInPictureControllerDelegate, ZegoCustomVideoRenderHandler>

@property (nonatomic, strong) AVPictureInPictureController *pipControl;

@property (nonatomic, strong) RCTView *rnVideoView;
@property (nonatomic, strong) AVSampleBufferDisplayLayer *rnLayer;

@property (nonatomic, strong) KitRemoteView *remoteVideoView;
@property (nonatomic, strong) AVSampleBufferDisplayLayer *remoteLayer;

@property (nonatomic, assign) ZegoViewMode viewMode;
@property (nonatomic, assign) BOOL inBackground;

@end

@implementation PipManager

+ (instancetype)sharedInstance {
  dispatch_once(&onceToken, ^{
    _instance = [[self alloc] init];
  });
  return _instance;
}

- (instancetype)init {
  self = [super init];
  if (self) {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleApplicationDidBecomeActive:)
                                                 name:UIApplicationDidBecomeActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleApplicationDidEnterBackground:)
                                                 name:UIApplicationDidEnterBackgroundNotification object:nil];
  }
  return self;
}

- (void)startPlayingStream:(NSString *)streamID rnVideoView:(RCTView *)rnVideoView viewMode:(ZegoViewMode)viewMode {
  self.viewMode = viewMode;
  
  // 为 rn view 添加用于自定义渲染的 layer，没找到就添加一个
  [self addRnLayerWithView:rnVideoView];
  
  [[ZegoExpressEngine sharedEngine] enableHardwareDecoder:YES];

  // 开始自定义渲染，在渲染回调中投递到不同 layer
  ZegoCustomVideoRenderConfig *renderConfig = [[ZegoCustomVideoRenderConfig alloc] init];
  renderConfig.bufferType = ZegoVideoBufferTypeCVPixelBuffer;
  renderConfig.frameFormatSeries = ZegoVideoFrameFormatSeriesRGB;

  NSLog(@"enableCustomVideoRender: YES");
  [[ZegoExpressEngine sharedEngine] enableCustomVideoRender:YES config:renderConfig];
  [[ZegoExpressEngine sharedEngine] setCustomVideoRenderHandler:self];
  [[ZegoExpressEngine sharedEngine] startPlayingStream:streamID];

  // 如果 pip 可用
  if (@available(iOS 15.0, *)) {
    if ([AVPictureInPictureController isPictureInPictureSupported]) {
      // PIP 配置
      NSError *error = nil;
      [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:&error];
      [[AVAudioSession sharedInstance] setActive:YES error:nil];
      if (error) {
          NSLog(@"PermissionFailed to set audio session, error:%@", error);
      }

      AVPictureInPictureVideoCallViewController *pipCallVC = [AVPictureInPictureVideoCallViewController new];
      pipCallVC.preferredContentSize = CGSizeMake(9, 16);

      AVPictureInPictureControllerContentSource *contentSource = [[AVPictureInPictureControllerContentSource alloc] initWithActiveVideoCallSourceView:rnVideoView contentViewController:pipCallVC];

      self.pipControl = [[AVPictureInPictureController alloc] initWithContentSource:contentSource];
      self.pipControl.delegate = self;
      self.pipControl.canStartPictureInPictureAutomaticallyFromInline = YES;
      [self.pipControl setValue:[NSNumber numberWithInt:1] forKey:@"controlsStyle"];
      
      self.remoteVideoView = [[KitRemoteView alloc] initWithFrame:CGRectZero];
      [pipCallVC.view addSubview:self.remoteVideoView];
      
      self.remoteVideoView.translatesAutoresizingMaskIntoConstraints = FALSE;
      [self.remoteVideoView mas_makeConstraints:^(MASConstraintMaker *make) {
          make.edges.equalTo(pipCallVC.view);
      }];
      
      self.remoteLayer = [self createAVSampleBufferDisplayLayerWithViewMode:self.viewMode];
      [self.remoteVideoView addDisplayLayer:self.remoteLayer];
    }
  }
}

- (void)stopPlayingStream:(NSString *)streamID {
  [[ZegoExpressEngine sharedEngine] stopPlayingStream:streamID];
  NSLog(@"enableCustomVideoRender: NO");
  [[ZegoExpressEngine sharedEngine] enableCustomVideoRender:NO config:NULL];
  [self enableMultiTaskForSDK:FALSE];
  
  [self.rnVideoView removeObserver:self forKeyPath:@"bounds"];
  self.rnLayer = NULL;
  self.rnVideoView = NULL;
  
  self.remoteLayer = NULL;
  self.remoteVideoView = NULL;
}

- (void)notifyPagePipEnable:(BOOL)pipEnable pageName:(NSString *)pageName {
  if (!pipEnable) {
    [self.pipControl stopPictureInPicture];
    self.pipControl = NULL;
  }
}

- (AVSampleBufferDisplayLayer *)createAVSampleBufferDisplayLayerWithViewMode:(ZegoViewMode)viewMode
{
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

- (void)enableMultiTaskForSDK:(BOOL)enable
{
    NSString *params = nil;
    if (enable){
        params = @"{\"method\":\"liveroom.video.enable_ios_multitask\",\"params\":{\"enable\":true}}";
        [[ZegoExpressEngine sharedEngine] callExperimentalAPI:params];
    } else {
        params = @"{\"method\":\"liveroom.video.enable_ios_multitask\",\"params\":{\"enable\":false}}";
        [[ZegoExpressEngine sharedEngine] callExperimentalAPI:params];
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if ([keyPath isEqualToString:@"bounds"] && object == self.rnVideoView) {
      CGRect newBounds = [[change objectForKey:NSKeyValueChangeNewKey] CGRectValue];
      self.rnLayer.frame = newBounds;
    }
}

- (void)handleApplicationDidBecomeActive:(NSNotification *)notify {
  NSLog(@"handleApplicationDidBecomeActive");
  self.inBackground = NO;

  if (self.pipControl.pictureInPictureActive) {
    [self.pipControl stopPictureInPicture];
  }
}
  
- (void)handleApplicationDidEnterBackground:(NSNotification *)notify {
  NSLog(@"handleApplicationDidEnterBackground");
  self.inBackground = YES;
}

#pragma mark - AVPictureInPictureControllerDelegate
- (void)pictureInPictureControllerWillStartPictureInPicture:(AVPictureInPictureController *)pictureInPictureController {
  NSLog(@"pictureInPictureController willStart");
  [self enableMultiTaskForSDK:TRUE];
}

- (void)pictureInPictureControllerDidStartPictureInPicture:(AVPictureInPictureController *)pictureInPictureController {
  NSLog(@"pictureInPictureController didStart");
}

- (void)pictureInPictureController:(AVPictureInPictureController *)pictureInPictureController failedToStartPictureInPictureWithError:(NSError *)error {
  NSLog(@"pictureInPictureController failedToStart, error: %@", error);
}

- (void)pictureInPictureControllerWillStopPictureInPicture:(AVPictureInPictureController *)pictureInPictureController {
  NSLog(@"pictureInPictureController willStop");
  [self enableMultiTaskForSDK:FALSE];
}

- (void)pictureInPictureControllerDidStopPictureInPicture:(AVPictureInPictureController *)pictureInPictureController {
  NSLog(@"pictureInPictureController didStop");
}

- (void)pictureInPictureController:(AVPictureInPictureController *)pictureInPictureController restoreUserInterfaceForPictureInPictureStopWithCompletionHandler:(void (^)(BOOL restored))completionHandler {
  NSLog(@"pictureInPictureController restoreUserInterface");
  completionHandler(YES);
}

#pragma mark - ZegoCustomVideoRenderHandler
- (void)onRemoteVideoFrameCVPixelBuffer:(CVPixelBufferRef)buffer param:(ZegoVideoFrameParam *)param streamID:(NSString *)streamID
{
    AVSampleBufferDisplayLayer *destLayer = self.inBackground ? self.remoteLayer : self.rnLayer;
  
    CMSampleBufferRef sampleBuffer = [self createSampleBuffer:buffer];
    if (sampleBuffer) {
        [destLayer enqueueSampleBuffer:sampleBuffer];
        if (destLayer.status == AVQueuedSampleBufferRenderingStatusFailed) {
            if (-11847 == destLayer.error.code) {
              if (destLayer == self.remoteLayer) {
                [self performSelectorOnMainThread:@selector(rebuildRemoteLayer) withObject:NULL waitUntilDone:YES];
              } else if (destLayer == self.rnLayer) {
                [self performSelectorOnMainThread:@selector(rebuildRNLayer) withObject:NULL waitUntilDone:YES];
              }
            }
        }
        CFRelease(sampleBuffer);
    }
}

- (CMSampleBufferRef)createSampleBuffer:(CVPixelBufferRef)pixelBuffer
{
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
    result = CMSampleBufferCreateForImageBuffer(kCFAllocatorDefault,pixelBuffer, true, NULL, NULL, videoInfo, &timing, &sampleBuffer);
    NSParameterAssert(result == 0 && sampleBuffer != NULL);
    CFRelease(videoInfo);
    CFArrayRef attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, YES);
    CFMutableDictionaryRef dict = (CFMutableDictionaryRef)CFArrayGetValueAtIndex(attachments, 0);
    CFDictionarySetValue(dict, kCMSampleAttachmentKey_DisplayImmediately, kCFBooleanTrue);
    return sampleBuffer;
}

- (void)addRnLayerWithView:(RCTView *)rnView {
  NSLog(@"addRnLayerWithView, frame: %@", NSStringFromCGRect(rnView.frame));
  if (self.rnVideoView != rnView) {
    [self.rnVideoView removeObserver:self forKeyPath:@"bounds"];
    self.rnVideoView = rnView;
  } else {
    self.rnLayer.frame = rnView.frame;
  }
  
  BOOL isFoundLayer = FALSE;
  for (CALayer *layer in self.rnVideoView.layer.sublayers) {
      if ([layer.name isEqualToString:kKitDisplayLayerName]) {
        isFoundLayer = TRUE;
        self.rnLayer = (AVSampleBufferDisplayLayer *)layer;
        break;
      }
  }
  
  if (!isFoundLayer) {
    self.rnLayer = [self createAVSampleBufferDisplayLayerWithViewMode:self.viewMode];
    self.rnLayer.name = kKitDisplayLayerName;
    [self.rnVideoView.layer addSublayer:self.rnLayer];
    self.rnLayer.frame = self.rnVideoView.bounds;
    
    NSLog(@"add rnlayer: %@ in rnView: %@", self.rnLayer, self.rnVideoView);
  }
  
  [self.rnVideoView addObserver:self forKeyPath:@"bounds" options:NSKeyValueObservingOptionNew context:nil];
}

- (void)rebuildRNLayer {
  NSLog(@"rebuildRNLayer");

  @synchronized(self) {
    if (self.rnLayer) {
      [self.rnLayer removeFromSuperlayer];
      self.rnLayer = nil;
    }
  
    [self addRnLayerWithView:self.rnVideoView];
  }
}

- (void)rebuildRemoteLayer {
  NSLog(@"rebuildRemoteLayer");

  @synchronized(self) {
    if (self.remoteLayer) {
      [self.remoteLayer removeFromSuperlayer];
      self.remoteLayer = nil;
    }
  
    self.remoteLayer = [self createAVSampleBufferDisplayLayerWithViewMode:self.viewMode];
    [self.remoteVideoView addDisplayLayer:self.remoteLayer];
  }
}

@end

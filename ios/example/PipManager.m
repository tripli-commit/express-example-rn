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

// for playing stream
@property (nonatomic, assign) ZegoViewMode playingViewMode;
@property (nonatomic, strong) RCTView *rnPlayingView;
@property (nonatomic, strong) AVSampleBufferDisplayLayer *rnPlayingLayer;

@property (nonatomic, strong) KitRemoteView *pipPlayingView;
@property (nonatomic, strong) AVSampleBufferDisplayLayer *pipPlayingLayer;

// for preview
@property (nonatomic, assign) ZegoViewMode previewViewMode;
@property (nonatomic, strong) RCTView *rnPreviewView;
@property (nonatomic, strong) AVSampleBufferDisplayLayer *rnPreviewLayer;

@property (nonatomic, assign) BOOL inBackground;

@property (nonatomic, assign) BOOL isCustomVideoRenderEnabled;

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

- (void)startPlayingStream:(NSString *)streamID rnPlayingView:(RCTView *)rnPlayingView viewMode:(ZegoViewMode)viewMode {
  self.playingViewMode = viewMode;
  
  // 为 rn view 添加用于自定义渲染的 layer，没找到就添加一个
  [self addRnLayerWithPlayingView:rnPlayingView];
  
  [self enableCustomVideoRender];
  
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

      AVPictureInPictureControllerContentSource *contentSource = [[AVPictureInPictureControllerContentSource alloc] initWithActiveVideoCallSourceView:rnPlayingView contentViewController:pipCallVC];

      self.pipControl = [[AVPictureInPictureController alloc] initWithContentSource:contentSource];
      self.pipControl.delegate = self;
      self.pipControl.canStartPictureInPictureAutomaticallyFromInline = YES;
      [self.pipControl setValue:[NSNumber numberWithInt:1] forKey:@"controlsStyle"];
      
      self.pipPlayingView = [[KitRemoteView alloc] initWithFrame:CGRectZero];
      [pipCallVC.view addSubview:self.pipPlayingView];
      
      self.pipPlayingView.translatesAutoresizingMaskIntoConstraints = FALSE;
      [self.pipPlayingView mas_makeConstraints:^(MASConstraintMaker *make) {
          make.edges.equalTo(pipCallVC.view);
      }];
      
      self.pipPlayingLayer = [self createAVSampleBufferDisplayLayerWithViewMode:self.playingViewMode];
      [self.pipPlayingView addDisplayLayer:self.pipPlayingLayer];
    }
  }
}

- (void)stopPlayingStream:(NSString *)streamID {
  [[ZegoExpressEngine sharedEngine] stopPlayingStream:streamID];

  // Don't disable customVideoRender, otherwise you’ll encounter error 1011003.
//  NSLog(@"enableCustomVideoRender: NO");
//  [[ZegoExpressEngine sharedEngine] enableCustomVideoRender:NO config:NULL];

  [self enableMultiTaskForSDK:FALSE];
  
  [self.rnPlayingView removeObserver:self forKeyPath:@"bounds"];
  self.rnPlayingLayer = NULL;
  self.rnPlayingView = NULL;
  
  self.pipPlayingLayer = NULL;
  self.pipPlayingView = NULL;
}

- (void)startPreview:(RCTView *)rnPreviewView viewMode:(ZegoViewMode)viewMode {
  self.previewViewMode = viewMode;
  
  // 为 rn view 添加用于自定义渲染的 layer，没找到就添加一个
  [self addRnLayerWithPreviewView:rnPreviewView];

  [self enableCustomVideoRender];
  
  [[ZegoExpressEngine sharedEngine] startPreview];
}

- (void)stopPreview {
  [[ZegoExpressEngine sharedEngine] stopPreview];
  
  [self.rnPreviewView removeObserver:self forKeyPath:@"bounds"];
  self.rnPreviewLayer = NULL;
  self.rnPreviewView = NULL;
}

- (void)notifyPagePipEnable:(BOOL)pipEnable pageName:(NSString *)pageName {
  if (!pipEnable) {
    [self.pipControl stopPictureInPicture];
    self.pipControl = NULL;
  }
}

- (void)enableCustomVideoRender {
  if (NO == self.isCustomVideoRenderEnabled) {
    [[ZegoExpressEngine sharedEngine] enableHardwareDecoder:YES];

    // 开始自定义渲染，在渲染回调中投递到不同 layer
    ZegoCustomVideoRenderConfig *renderConfig = [[ZegoCustomVideoRenderConfig alloc] init];
    renderConfig.bufferType = ZegoVideoBufferTypeCVPixelBuffer;
    renderConfig.frameFormatSeries = ZegoVideoFrameFormatSeriesRGB;

    NSLog(@"enableCustomVideoRender: YES");
    [[ZegoExpressEngine sharedEngine] enableCustomVideoRender:YES config:renderConfig];
    [[ZegoExpressEngine sharedEngine] setCustomVideoRenderHandler:self];
    
    self.isCustomVideoRenderEnabled = YES;
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

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if ([keyPath isEqualToString:@"bounds"]) {
      CGRect newBounds = [[change objectForKey:NSKeyValueChangeNewKey] CGRectValue];
      if (object == self.rnPlayingView) {
        self.rnPlayingLayer.frame = newBounds;
      } else if (object == self.rnPreviewView) {
        self.rnPreviewLayer.frame = newBounds;
      }
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

- (void)onRemoteVideoFrameCVPixelBuffer:(CVPixelBufferRef)buffer
                                  param:(ZegoVideoFrameParam *)param
                               streamID:(NSString *)streamID
{
    AVSampleBufferDisplayLayer *destLayer = self.inBackground ? self.pipPlayingLayer : self.rnPlayingLayer;
  
    CMSampleBufferRef sampleBuffer = [self createSampleBuffer:buffer];
    if (sampleBuffer) {
        [destLayer enqueueSampleBuffer:sampleBuffer];
        if (destLayer.status == AVQueuedSampleBufferRenderingStatusFailed) {
            if (-11847 == destLayer.error.code) {
              if (destLayer == self.pipPlayingLayer) {
                [self performSelectorOnMainThread:@selector(rebuildPipPlayingLayer) withObject:NULL waitUntilDone:YES];
              } else if (destLayer == self.rnPlayingLayer) {
                [self performSelectorOnMainThread:@selector(rebuildRnPlayingLayer) withObject:NULL waitUntilDone:YES];
              }
            }
        }
        CFRelease(sampleBuffer);
    }
}

- (void)onCapturedVideoFrameCVPixelBuffer:(CVPixelBufferRef)buffer
                                    param:(ZegoVideoFrameParam *)param
                                 flipMode:(ZegoVideoFlipMode)flipMode
                                  channel:(ZegoPublishChannel)channel
{
    AVSampleBufferDisplayLayer *destLayer = self.rnPreviewLayer;

    CMSampleBufferRef sampleBuffer = [self createSampleBuffer:buffer];
    if (sampleBuffer) {
        [destLayer enqueueSampleBuffer:sampleBuffer];
        if (destLayer.status == AVQueuedSampleBufferRenderingStatusFailed) {
            if (-11847 == destLayer.error.code) {
                [self performSelectorOnMainThread:@selector(rebuildRnPreviewLayer) withObject:NULL waitUntilDone:YES];
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

- (void)addRnLayerWithPlayingView:(RCTView *)rnView {
  NSLog(@"addRnLayerWithPlayingView, frame: %@", NSStringFromCGRect(rnView.frame));
  if (self.rnPlayingView != rnView) {
    [self.rnPlayingView removeObserver:self forKeyPath:@"bounds"];
    self.rnPlayingView = rnView;
  } else {
    self.rnPlayingLayer.frame = rnView.frame;
  }
  
  BOOL isFoundLayer = FALSE;
  for (CALayer *layer in self.rnPlayingView.layer.sublayers) {
      if ([layer.name isEqualToString:kKitDisplayLayerName]) {
        isFoundLayer = TRUE;
        self.rnPlayingLayer = (AVSampleBufferDisplayLayer *)layer;
        break;
      }
  }
  
  if (!isFoundLayer) {
    self.rnPlayingLayer = [self createAVSampleBufferDisplayLayerWithViewMode:self.playingViewMode];
    self.rnPlayingLayer.name = kKitDisplayLayerName;
    [self.rnPlayingView.layer addSublayer:self.rnPlayingLayer];
    self.rnPlayingLayer.frame = self.rnPlayingView.bounds;
    
    NSLog(@"add rnlayer: %@ in rnView: %@", self.rnPlayingLayer, self.rnPlayingView);
  }
  
  [self.rnPlayingView addObserver:self forKeyPath:@"bounds" options:NSKeyValueObservingOptionNew context:nil];
}

- (void)addRnLayerWithPreviewView:(RCTView *)rnView {
  NSLog(@"addRnLayerWithPreviewView, frame: %@", NSStringFromCGRect(rnView.frame));
  if (self.rnPreviewView != rnView) {
    [self.rnPreviewView removeObserver:self forKeyPath:@"bounds"];
    self.rnPreviewView = rnView;
  } else {
    self.rnPreviewLayer.frame = rnView.frame;
  }
  
  BOOL isFoundLayer = FALSE;
  for (CALayer *layer in self.rnPreviewView.layer.sublayers) {
      if ([layer.name isEqualToString:kKitDisplayLayerName]) {
        isFoundLayer = TRUE;
        self.rnPreviewLayer = (AVSampleBufferDisplayLayer *)layer;
        break;
      }
  }
  
  if (!isFoundLayer) {
    self.rnPreviewLayer = [self createAVSampleBufferDisplayLayerWithViewMode:self.previewViewMode];
    self.rnPreviewLayer.name = kKitDisplayLayerName;
    [self.rnPreviewView.layer addSublayer:self.rnPreviewLayer];
    self.rnPreviewLayer.frame = self.rnPreviewView.bounds;
    
    NSLog(@"add rnlayer: %@ in rnView: %@", self.rnPreviewLayer, self.rnPreviewView);
  }
  
  [self.rnPreviewView addObserver:self forKeyPath:@"bounds" options:NSKeyValueObservingOptionNew context:nil];
}

- (void)rebuildRnPlayingLayer {
  NSLog(@"rebuildRnPlayingLayer");

  @synchronized(self) {
    if (self.rnPlayingLayer) {
      [self.rnPlayingLayer removeFromSuperlayer];
      self.rnPlayingLayer = nil;
    }
  
    [self addRnLayerWithPlayingView:self.rnPlayingView];
  }
}

- (void)rebuildRnPreviewLayer {
  NSLog(@"rebuildRnPreviewLayer");

  @synchronized(self) {
    if (self.rnPreviewLayer) {
      [self.rnPreviewLayer removeFromSuperlayer];
      self.rnPreviewLayer = nil;
    }
  
    [self addRnLayerWithPreviewView:self.rnPreviewView];
  }
}

- (void)rebuildPipPlayingLayer {
  NSLog(@"rebuildPipPlayingLayer");

  @synchronized(self) {
    if (self.pipPlayingLayer) {
      [self.pipPlayingLayer removeFromSuperlayer];
      self.pipPlayingLayer = nil;
    }
  
    self.pipPlayingLayer = [self createAVSampleBufferDisplayLayerWithViewMode:self.playingViewMode];
    [self.pipPlayingView addDisplayLayer:self.pipPlayingLayer];
  }
}

@end

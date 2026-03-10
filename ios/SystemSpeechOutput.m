// 3SenseApp/packages/system-speech-output/ios/SystemSpeechOutput.m
#import "SystemSpeechOutput.h"

#import <AVFoundation/AVFoundation.h>

@interface SystemSpeechOutput() <AVSpeechSynthesizerDelegate>
@property (nonatomic, strong) AVSpeechSynthesizer *synthesizer;
@property (nonatomic, assign) BOOL hasListeners;
@end

@implementation SystemSpeechOutput

RCT_EXPORT_MODULE();

+ (BOOL)requiresMainQueueSetup
{
  return YES;
}

- (instancetype)init
{
  if ((self = [super init])) {
    _synthesizer = [AVSpeechSynthesizer new];
    _synthesizer.delegate = self;
  }
  return self;
}

- (NSArray<NSString *> *)supportedEvents
{
  return @[@"SystemSpeechOutputState"];
}

- (void)startObserving
{
  self.hasListeners = YES;
}

- (void)stopObserving
{
  self.hasListeners = NO;
}

RCT_EXPORT_METHOD(addListener:(NSString *)eventName)
{
  // Required by NativeEventEmitter on newer React Native versions.
}

RCT_EXPORT_METHOD(removeListeners:(double)count)
{
  // Required by NativeEventEmitter on newer React Native versions.
}

RCT_EXPORT_METHOD(isAvailable:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject)
{
  resolve(@(YES));
}

RCT_EXPORT_METHOD(speak:(NSString *)text options:(NSDictionary *)options resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject)
{
  dispatch_async(dispatch_get_main_queue(), ^{
    [self.synthesizer stopSpeakingAtBoundary:AVSpeechBoundaryImmediate];

    AVSpeechUtterance *utterance = [[AVSpeechUtterance alloc] initWithString:text ?: @""];
    NSString *language = [options[@"language"] isKindOfClass:[NSString class]] ? options[@"language"] : nil;
    NSNumber *rate = [options[@"rate"] isKindOfClass:[NSNumber class]] ? options[@"rate"] : nil;

    if (language.length > 0) {
      AVSpeechSynthesisVoice *voice = [AVSpeechSynthesisVoice voiceWithLanguage:language];
      if (voice != nil) {
        utterance.voice = voice;
      }
    }

    if (rate != nil) {
      utterance.rate = rate.floatValue;
    }

    [self.synthesizer speakUtterance:utterance];
    [self emitState:@"speaking"];
    resolve(@(YES));
  });
}

RCT_EXPORT_METHOD(stop:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject)
{
  dispatch_async(dispatch_get_main_queue(), ^{
    [self.synthesizer stopSpeakingAtBoundary:AVSpeechBoundaryImmediate];
    [self emitState:@"idle"];
    resolve(@(YES));
  });
}

- (void)speechSynthesizer:(AVSpeechSynthesizer *)synthesizer didFinishSpeechUtterance:(AVSpeechUtterance *)utterance
{
  [self emitState:@"idle"];
}

- (void)speechSynthesizer:(AVSpeechSynthesizer *)synthesizer didCancelSpeechUtterance:(AVSpeechUtterance *)utterance
{
  [self emitState:@"idle"];
}

- (void)speechSynthesizer:(AVSpeechSynthesizer *)synthesizer didStartSpeechUtterance:(AVSpeechUtterance *)utterance
{
  [self emitState:@"speaking"];
}

- (void)emitState:(NSString *)state
{
  if (!self.hasListeners) {
    return;
  }
  [self sendEventWithName:@"SystemSpeechOutputState" body:@{ @"state": state ?: @"idle" }];
}

@end

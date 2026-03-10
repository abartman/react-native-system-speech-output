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

    NSDictionary *safeOptions = [options isKindOfClass:[NSDictionary class]] ? options : @{};
    [self configureSynthesizerForOptions:safeOptions];

    AVSpeechUtterance *utterance = [self buildUtteranceForText:text options:safeOptions];
    if (utterance == nil) {
      reject(@"speech_output_unavailable", @"Unable to create speech utterance.", nil);
      return;
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

- (AVSpeechUtterance *)buildUtteranceForText:(NSString *)text options:(NSDictionary *)options
{
  NSString *spokenText = [text isKindOfClass:[NSString class]] ? text : @"";
  NSString *ssml = [options[@"ssml"] isKindOfClass:[NSString class]] ? options[@"ssml"] : nil;

  AVSpeechUtterance *utterance = nil;
  if (ssml.length > 0) {
    if (@available(iOS 16.0, *)) {
      utterance = [[AVSpeechUtterance alloc] initWithSSMLRepresentation:ssml];
    }
  }

  if (utterance == nil) {
    utterance = [[AVSpeechUtterance alloc] initWithString:spokenText ?: @""];
  }

  NSNumber *preferAssistiveSettings = [options[@"preferAssistiveTechnologySettings"] isKindOfClass:[NSNumber class]]
    ? options[@"preferAssistiveTechnologySettings"]
    : @(YES);
  utterance.prefersAssistiveTechnologySettings = preferAssistiveSettings.boolValue;

  NSNumber *rate = [options[@"rate"] isKindOfClass:[NSNumber class]] ? options[@"rate"] : nil;
  if (rate != nil) {
    float clampedRate = MAX(AVSpeechUtteranceMinimumSpeechRate,
                            MIN(AVSpeechUtteranceMaximumSpeechRate, rate.floatValue));
    utterance.rate = clampedRate;
  }

  NSString *voiceIdentifier = [options[@"voiceIdentifier"] isKindOfClass:[NSString class]]
    ? options[@"voiceIdentifier"]
    : nil;
  NSString *language = [options[@"language"] isKindOfClass:[NSString class]] ? options[@"language"] : nil;

  AVSpeechSynthesisVoice *voice = nil;
  if (voiceIdentifier.length > 0) {
    voice = [AVSpeechSynthesisVoice voiceWithIdentifier:voiceIdentifier];
  }
  if (voice == nil && language.length > 0) {
    voice = [self preferredVoiceForLanguage:language];
  }
  if (voice != nil) {
    utterance.voice = voice;
  }

  return utterance;
}

- (void)configureSynthesizerForOptions:(NSDictionary *)options
{
  BOOL useSystemAudioSession = YES;
  NSNumber *useSystemAudioSessionOption = [options[@"useSystemAudioSession"] isKindOfClass:[NSNumber class]]
    ? options[@"useSystemAudioSession"]
    : nil;
  if (useSystemAudioSessionOption != nil) {
    useSystemAudioSession = useSystemAudioSessionOption.boolValue;
  }

  if ([self.synthesizer respondsToSelector:@selector(setUsesApplicationAudioSession:)]) {
    self.synthesizer.usesApplicationAudioSession = !useSystemAudioSession;
  }
}

- (AVSpeechSynthesisVoice *)preferredVoiceForLanguage:(NSString *)language
{
  NSString *normalized = [self normalizedLanguageCode:language];
  if (normalized.length == 0) {
    return nil;
  }

  NSString *targetBase = [[normalized componentsSeparatedByString:@"-"] firstObject] ?: normalized;
  NSArray<AVSpeechSynthesisVoice *> *voices = [AVSpeechSynthesisVoice speechVoices];

  AVSpeechSynthesisVoice *bestExact = nil;
  NSInteger bestExactScore = NSIntegerMin;
  AVSpeechSynthesisVoice *bestBase = nil;
  NSInteger bestBaseScore = NSIntegerMin;

  for (AVSpeechSynthesisVoice *voice in voices) {
    NSString *voiceLanguage = [self normalizedLanguageCode:voice.language];
    if (voiceLanguage.length == 0) {
      continue;
    }

    NSString *voiceBase = [[voiceLanguage componentsSeparatedByString:@"-"] firstObject] ?: voiceLanguage;
    NSInteger qualityScore = (NSInteger)voice.quality;

    if ([voiceLanguage isEqualToString:normalized]) {
      if (qualityScore > bestExactScore) {
        bestExact = voice;
        bestExactScore = qualityScore;
      }
      continue;
    }

    if ([voiceBase isEqualToString:targetBase] && qualityScore > bestBaseScore) {
      bestBase = voice;
      bestBaseScore = qualityScore;
    }
  }

  if (bestExact != nil) {
    return bestExact;
  }
  if (bestBase != nil) {
    return bestBase;
  }
  return [AVSpeechSynthesisVoice voiceWithLanguage:normalized];
}

- (NSString *)normalizedLanguageCode:(NSString *)language
{
  if (![language isKindOfClass:[NSString class]]) {
    return nil;
  }

  NSString *trimmed = [[language stringByReplacingOccurrencesOfString:@"_" withString:@"-"]
    stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
  if (trimmed.length == 0) {
    return nil;
  }
  return trimmed.lowercaseString;
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

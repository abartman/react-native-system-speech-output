#import "SystemSpeechOutput.h"

#import <AVFoundation/AVFoundation.h>

@interface SystemSpeechOutput() <AVSpeechSynthesizerDelegate>
@property (nonatomic, strong) AVSpeechSynthesizer *synthesizer;
@property (nonatomic, strong) NSMapTable<AVSpeechUtterance *, NSString *> *utteranceIds;
@property (nonatomic, assign) BOOL hasListeners;
@end

@implementation SystemSpeechOutput

RCT_EXPORT_MODULE(SystemSpeechOutput);

+ (BOOL)requiresMainQueueSetup
{
  return YES;
}

- (instancetype)init
{
  if ((self = [super init])) {
    _synthesizer = [AVSpeechSynthesizer new];
    _synthesizer.delegate = self;
    _utteranceIds = [NSMapTable strongToStrongObjectsMapTable];
  }
  return self;
}

- (NSArray<NSString *> *)supportedEvents
{
  return @[@"SystemSpeechOutputState", @"SystemSpeechOutputProgress"];
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

RCT_EXPORT_METHOD(isAvailable:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject)
{
  resolve(@(YES));
}

RCT_EXPORT_METHOD(listVoices:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject)
{
  resolve([self serializedVoices:[AVSpeechSynthesisVoice speechVoices]]);
}

RCT_EXPORT_METHOD(speak:(NSString *)text options:(NSDictionary *)options resolve:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject)
{
  dispatch_async(dispatch_get_main_queue(), ^{
    [self.synthesizer stopSpeakingAtBoundary:AVSpeechBoundaryImmediate];
    [self.utteranceIds removeAllObjects];

    NSDictionary *safeOptions = [options isKindOfClass:[NSDictionary class]] ? options : @{};
    [self configureSynthesizerForOptions:safeOptions];

    AVSpeechUtterance *utterance = [self buildUtteranceForText:text options:safeOptions];
    if (utterance == nil) {
      reject(@"speech_output_unavailable", @"Unable to create speech utterance.", nil);
      return;
    }

    NSString *utteranceId = [[NSUUID UUID] UUIDString];
    [self.utteranceIds setObject:utteranceId forKey:utterance];

    [self.synthesizer speakUtterance:utterance];
    [self emitState:@"speaking"];
    resolve(@(YES));
  });
}

RCT_EXPORT_METHOD(stop:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject)
{
  dispatch_async(dispatch_get_main_queue(), ^{
    [self.synthesizer stopSpeakingAtBoundary:AVSpeechBoundaryImmediate];
    [self.utteranceIds removeAllObjects];
    [self emitState:@"idle"];
    resolve(@(YES));
  });
}

- (NSArray<NSDictionary *> *)serializedVoices:(NSArray<AVSpeechSynthesisVoice *> *)voices
{
  NSMutableArray<NSDictionary *> *results = [NSMutableArray new];

  for (AVSpeechSynthesisVoice *voice in voices) {
    NSMutableDictionary *entry = [NSMutableDictionary new];
    entry[@"name"] = voice.identifier ?: voice.name ?: voice.language ?: @"";
    if (voice.language.length > 0) {
      entry[@"locale"] = [self normalizedLanguageCode:voice.language];
    }
    entry[@"quality"] = @((NSInteger)voice.quality);
    entry[@"features"] = @[];
    [results addObject:entry];
  }

  return results;
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

- (NSString *)utteranceIdForUtterance:(AVSpeechUtterance *)utterance
{
  if (utterance == nil) {
    return nil;
  }
  return [self.utteranceIds objectForKey:utterance];
}

- (void)clearTrackingForUtterance:(AVSpeechUtterance *)utterance
{
  if (utterance == nil) {
    return;
  }
  [self.utteranceIds removeObjectForKey:utterance];
}

- (void)emitProgressForRange:(NSRange)characterRange utterance:(AVSpeechUtterance *)utterance
{
  if (!self.hasListeners) {
    return;
  }

  NSString *utteranceId = [self utteranceIdForUtterance:utterance];
  if (utteranceId.length == 0) {
    return;
  }

  NSUInteger start = characterRange.location;
  NSUInteger end = NSMaxRange(characterRange);

  [self sendEventWithName:@"SystemSpeechOutputProgress"
                     body:@{
                       @"utteranceId": utteranceId,
                       @"start": @(start),
                       @"end": @(end),
                     }];
}

- (void)speechSynthesizer:(AVSpeechSynthesizer *)synthesizer willSpeakRangeOfSpeechString:(NSRange)characterRange utterance:(AVSpeechUtterance *)utterance
{
  [self emitProgressForRange:characterRange utterance:utterance];
}

- (void)speechSynthesizer:(AVSpeechSynthesizer *)synthesizer didFinishSpeechUtterance:(AVSpeechUtterance *)utterance
{
  [self clearTrackingForUtterance:utterance];
  [self emitState:@"idle"];
}

- (void)speechSynthesizer:(AVSpeechSynthesizer *)synthesizer didCancelSpeechUtterance:(AVSpeechUtterance *)utterance
{
  [self clearTrackingForUtterance:utterance];
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

#ifdef RCT_NEW_ARCH_ENABLED
- (std::shared_ptr<facebook::react::TurboModule>)getTurboModule:
  (const facebook::react::ObjCTurboModule::InitParams &)params
{
  return std::make_shared<facebook::react::NativeSystemSpeechOutputSpecJSI>(params);
}
#endif

@end

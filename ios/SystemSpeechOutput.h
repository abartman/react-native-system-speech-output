#import <React/RCTBridgeModule.h>
#import <React/RCTEventEmitter.h>

#ifdef RCT_NEW_ARCH_ENABLED
#import <NativeSystemSpeechOutputSpec/NativeSystemSpeechOutputSpec.h>
#endif

@interface SystemSpeechOutput : RCTEventEmitter <RCTBridgeModule>
@end

#ifdef RCT_NEW_ARCH_ENABLED
@interface SystemSpeechOutput () <NativeSystemSpeechOutputSpec>
@end
#endif

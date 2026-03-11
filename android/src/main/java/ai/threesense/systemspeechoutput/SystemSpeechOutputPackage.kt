package ai.threesense.systemspeechoutput

import com.facebook.react.BaseReactPackage
import com.facebook.react.bridge.NativeModule
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.module.model.ReactModuleInfo
import com.facebook.react.module.model.ReactModuleInfoProvider

class SystemSpeechOutputPackage : BaseReactPackage() {
  override fun getModule(name: String, reactContext: ReactApplicationContext): NativeModule? =
    if (name == SystemSpeechOutputImpl.NAME) {
      SystemSpeechOutputModule(reactContext)
    } else {
      null
    }

  override fun getReactModuleInfoProvider(): ReactModuleInfoProvider = ReactModuleInfoProvider {
    mapOf(
      SystemSpeechOutputImpl.NAME to ReactModuleInfo(
        name = SystemSpeechOutputImpl.NAME,
        className = SystemSpeechOutputModule::class.java.name,
        canOverrideExistingModule = false,
        needsEagerInit = false,
        isCxxModule = false,
        isTurboModule = BuildConfig.IS_NEW_ARCHITECTURE_ENABLED,
      )
    )
  }
}

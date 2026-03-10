// 3SenseApp/packages/system-speech-output/android/src/main/java/ai/threesense/systemspeechoutput/SystemSpeechOutputPackage.kt
package ai.threesense.systemspeechoutput

import com.facebook.react.ReactPackage
import com.facebook.react.bridge.NativeModule
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.uimanager.ViewManager

class SystemSpeechOutputPackage : ReactPackage {
  override fun createNativeModules(reactContext: ReactApplicationContext): List<NativeModule> {
    return listOf(SystemSpeechOutputModule(reactContext))
  }

  override fun createViewManagers(
    reactContext: ReactApplicationContext,
  ): List<ViewManager<*, *>> {
    return emptyList()
  }
}

package ai.threesense.systemspeechoutput

import com.facebook.react.bridge.Promise
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.ReactContextBaseJavaModule
import com.facebook.react.bridge.ReactMethod
import com.facebook.react.bridge.ReadableMap

class SystemSpeechOutputModule(reactContext: ReactApplicationContext) :
  ReactContextBaseJavaModule(reactContext) {

  private val implementation = SystemSpeechOutputImpl(reactContext)

  override fun getName(): String = SystemSpeechOutputImpl.NAME

  override fun initialize() {
    super.initialize()
    implementation.initialize()
  }

  override fun invalidate() {
    implementation.invalidate()
    super.invalidate()
  }

  @ReactMethod
  fun addListener(eventName: String?) {
    implementation.addListener(eventName)
  }

  @ReactMethod
  fun removeListeners(count: Double) {
    implementation.removeListeners(count)
  }

  @ReactMethod
  fun isAvailable(promise: Promise) {
    implementation.isAvailable(promise)
  }

  @ReactMethod
  fun listVoices(promise: Promise) {
    implementation.listVoices(promise)
  }

  @ReactMethod
  fun speak(text: String, options: ReadableMap?, promise: Promise) {
    implementation.speak(text, options, promise)
  }

  @ReactMethod
  fun stop(promise: Promise) {
    implementation.stop(promise)
  }
}

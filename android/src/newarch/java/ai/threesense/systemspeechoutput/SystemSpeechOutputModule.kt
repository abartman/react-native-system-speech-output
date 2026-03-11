package ai.threesense.systemspeechoutput

import com.facebook.react.bridge.Promise
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.ReadableMap

class SystemSpeechOutputModule(reactContext: ReactApplicationContext) :
  NativeSystemSpeechOutputSpec(reactContext) {

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

  override fun addListener(eventName: String) {
    implementation.addListener(eventName)
  }

  override fun removeListeners(count: Double) {
    implementation.removeListeners(count)
  }

  override fun isAvailable(promise: Promise) {
    implementation.isAvailable(promise)
  }

  override fun listVoices(promise: Promise) {
    implementation.listVoices(promise)
  }

  override fun speak(text: String, options: ReadableMap?, promise: Promise) {
    implementation.speak(text, options, promise)
  }

  override fun stop(promise: Promise) {
    implementation.stop(promise)
  }
}

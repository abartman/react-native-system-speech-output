// 3SenseApp/packages/system-speech-output/android/src/main/java/ai/threesense/systemspeechoutput/SystemSpeechOutputModule.kt
package ai.threesense.systemspeechoutput

import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.speech.tts.TextToSpeech
import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.Promise
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.ReactContextBaseJavaModule
import com.facebook.react.bridge.ReactMethod
import com.facebook.react.bridge.ReadableMap
import com.facebook.react.modules.core.DeviceEventManagerModule
import java.util.Locale
import java.util.UUID

class SystemSpeechOutputModule(private val reactContext: ReactApplicationContext) :
  ReactContextBaseJavaModule(reactContext), TextToSpeech.OnInitListener {

  private val mainHandler = Handler(Looper.getMainLooper())
  private var textToSpeech: TextToSpeech? = null
  private var initialized = false
  private var pendingSpeak: Triple<String, String?, Float?>? = null
  private var lastUtteranceId: String? = null

  override fun getName(): String = "SystemSpeechOutput"

  override fun initialize() {
    super.initialize()
    ensureTextToSpeech()
  }

  override fun invalidate() {
    super.invalidate()
    stopInternal()
    textToSpeech?.shutdown()
    textToSpeech = null
    initialized = false
    pendingSpeak = null
  }

  override fun onInit(status: Int) {
    initialized = status == TextToSpeech.SUCCESS
    if (!initialized) {
      emitState("error")
      return
    }

    textToSpeech?.setOnUtteranceProgressListener(object : android.speech.tts.UtteranceProgressListener() {
      override fun onStart(utteranceId: String?) {
        emitState("speaking")
      }

      override fun onDone(utteranceId: String?) {
        if (utteranceId != null && utteranceId == lastUtteranceId) {
          lastUtteranceId = null
          emitState("idle")
        }
      }

      override fun onError(utteranceId: String?) {
        if (utteranceId != null && utteranceId == lastUtteranceId) {
          lastUtteranceId = null
        }
        emitState("error")
      }
    })

    pendingSpeak?.let { (text, language, rate) ->
      pendingSpeak = null
      speakInternal(text, language, rate)
    }
  }

  @ReactMethod
  fun addListener(eventName: String?) {
    // Required by NativeEventEmitter on newer React Native versions.
  }

  @ReactMethod
  fun removeListeners(count: Double) {
    // Required by NativeEventEmitter on newer React Native versions.
  }

  @ReactMethod
  fun isAvailable(promise: Promise) {
    if (textToSpeech != null) {
      promise.resolve(true)
      return
    }

    mainHandler.post {
      if (textToSpeech == null) {
        textToSpeech = TextToSpeech(reactContext.applicationContext, this)
      }
      promise.resolve(true)
    }
  }

  @ReactMethod
  fun speak(text: String, options: ReadableMap?, promise: Promise) {
    ensureTextToSpeech()
    val language = options?.takeIf { it.hasKey("language") && !it.isNull("language") }?.getString("language")
    val rate = options?.takeIf { it.hasKey("rate") && !it.isNull("rate") }?.getDouble("rate")?.toFloat()

    if (!initialized) {
      pendingSpeak = Triple(text, language, rate)
      promise.resolve(true)
      return
    }

    speakInternal(text, language, rate)
    promise.resolve(true)
  }

  @ReactMethod
  fun stop(promise: Promise) {
    stopInternal()
    promise.resolve(true)
  }

  private fun ensureTextToSpeech() {
    if (textToSpeech != null) {
      return
    }

    mainHandler.post {
      if (textToSpeech == null) {
        textToSpeech = TextToSpeech(reactContext.applicationContext, this)
      }
    }
  }

  private fun speakInternal(text: String, language: String?, rate: Float?) {
    val engine = textToSpeech ?: return
    if (!language.isNullOrBlank()) {
      runCatching {
        engine.language = Locale.forLanguageTag(language)
      }
    }
    if (rate != null) {
      engine.setSpeechRate(rate)
    }
    val utteranceId = UUID.randomUUID().toString()
    lastUtteranceId = utteranceId
    val params = Bundle().apply {
      putString(TextToSpeech.Engine.KEY_PARAM_UTTERANCE_ID, utteranceId)
    }
    engine.speak(text, TextToSpeech.QUEUE_FLUSH, params, utteranceId)
  }

  private fun stopInternal() {
    lastUtteranceId = null
    textToSpeech?.stop()
    emitState("idle")
  }

  private fun emitState(state: String) {
    val payload = Arguments.createMap().apply {
      putString("state", state)
    }
    reactContext
      .getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter::class.java)
      .emit("SystemSpeechOutputState", payload)
  }
}

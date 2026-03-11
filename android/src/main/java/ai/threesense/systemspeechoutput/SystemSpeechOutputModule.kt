package ai.threesense.systemspeechoutput

import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.speech.tts.TextToSpeech
import android.speech.tts.Voice
import android.text.SpannableString
import android.text.Spanned
import android.text.style.TtsSpan
import android.util.Patterns
import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.Promise
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.ReactContextBaseJavaModule
import com.facebook.react.bridge.ReactMethod
import com.facebook.react.bridge.ReadableMap
import com.facebook.react.bridge.WritableArray
import com.facebook.react.modules.core.DeviceEventManagerModule
import java.util.Locale
import java.util.UUID
import java.util.regex.Pattern

private data class PendingSpeakRequest(
  val text: String,
  val language: String?,
  val rate: Float?,
  val pitch: Float?,
  val voiceName: String?,
)

class SystemSpeechOutputModule(private val reactContext: ReactApplicationContext) :
  ReactContextBaseJavaModule(reactContext), TextToSpeech.OnInitListener {

  private val mainHandler = Handler(Looper.getMainLooper())
  private var textToSpeech: TextToSpeech? = null
  private var initialized = false
  private var pendingSpeak: PendingSpeakRequest? = null
  private val pendingVoiceListPromises = mutableListOf<Promise>()
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
    pendingVoiceListPromises.clear()
  }

  override fun onInit(status: Int) {
    initialized = status == TextToSpeech.SUCCESS
    if (!initialized) {
      emitState("error")
      flushPendingVoicePromises()
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

    flushPendingVoicePromises()

    pendingSpeak?.let { request ->
      pendingSpeak = null
      speakInternal(
        text = request.text,
        language = request.language,
        rate = request.rate,
        pitch = request.pitch,
        voiceName = request.voiceName,
      )
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
  fun listVoices(promise: Promise) {
    ensureTextToSpeech()
    if (!initialized) {
      pendingVoiceListPromises.add(promise)
      return
    }
    promise.resolve(createVoicesArray(textToSpeech?.voices))
  }

  @ReactMethod
  fun speak(text: String, options: ReadableMap?, promise: Promise) {
    ensureTextToSpeech()
    val language = options?.takeIf { it.hasKey("language") && !it.isNull("language") }?.getString("language")
    val rate = options?.takeIf { it.hasKey("rate") && !it.isNull("rate") }?.getDouble("rate")?.toFloat()
    val pitch = options?.takeIf { it.hasKey("pitch") && !it.isNull("pitch") }?.getDouble("pitch")?.toFloat()
    val voiceName = options?.takeIf { it.hasKey("voiceName") && !it.isNull("voiceName") }?.getString("voiceName")

    if (!initialized) {
      pendingSpeak = PendingSpeakRequest(
        text = text,
        language = language,
        rate = rate,
        pitch = pitch,
        voiceName = voiceName,
      )
      promise.resolve(true)
      return
    }

    speakInternal(
      text = text,
      language = language,
      rate = rate,
      pitch = pitch,
      voiceName = voiceName,
    )
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

  private fun flushPendingVoicePromises() {
    if (pendingVoiceListPromises.isEmpty()) {
      return
    }
    val payload = if (initialized) createVoicesArray(textToSpeech?.voices) else Arguments.createArray()
    val promises = pendingVoiceListPromises.toList()
    pendingVoiceListPromises.clear()
    promises.forEach { it.resolve(payload) }
  }

  private fun speakInternal(
    text: String,
    language: String?,
    rate: Float?,
    pitch: Float?,
    voiceName: String?,
  ) {
    val engine = textToSpeech ?: return

    val locale = language
      ?.takeIf { it.isNotBlank() }
      ?.let { Locale.forLanguageTag(normalizeLanguageTag(it)) }

    val selectedVoice = selectVoice(engine, locale, voiceName)
    if (selectedVoice != null) {
      runCatching { engine.voice = selectedVoice }
    } else if (locale != null) {
      runCatching { engine.language = locale }
    }

    if (rate != null) {
      engine.setSpeechRate(rate.coerceIn(0.25f, 2.0f))
    }
    if (pitch != null) {
      engine.setPitch(pitch.coerceIn(0.5f, 2.0f))
    }

    val utteranceId = UUID.randomUUID().toString()
    lastUtteranceId = utteranceId
    val params = Bundle().apply {
      putString(TextToSpeech.Engine.KEY_PARAM_UTTERANCE_ID, utteranceId)
    }

    engine.speak(annotateForSpeech(text), TextToSpeech.QUEUE_FLUSH, params, utteranceId)
  }

  private fun selectVoice(
    engine: TextToSpeech,
    locale: Locale?,
    voiceName: String?,
  ): Voice? {
    val voices = engine.voices ?: return null

    if (!voiceName.isNullOrBlank()) {
      voices.firstOrNull { it.name.equals(voiceName, ignoreCase = true) }?.let { return it }
    }

    if (locale == null) {
      return null
    }

    val targetTag = locale.toLanguageTag().lowercase(Locale.US)
    val targetLanguage = locale.language.lowercase(Locale.US)

    return voices
      .mapNotNull { voice ->
        val score = scoreVoice(voice, targetTag, targetLanguage)
        if (score == Int.MIN_VALUE) null else voice to score
      }
      .sortedWith(
        compareByDescending<Pair<Voice, Int>> { it.second }
          .thenBy { it.first.latency }
          .thenBy { if (it.first.isNetworkConnectionRequired) 1 else 0 }
      )
      .firstOrNull()
      ?.first
  }

  private fun scoreVoice(
    voice: Voice,
    targetTag: String,
    targetLanguage: String,
  ): Int {
    val voiceLocale = voice.locale ?: return Int.MIN_VALUE
    val voiceTag = voiceLocale.toLanguageTag().lowercase(Locale.US)
    val voiceLanguage = voiceLocale.language.lowercase(Locale.US)

    val localeScore = when {
      voiceTag == targetTag -> 10_000
      voiceLanguage == targetLanguage -> 5_000
      else -> return Int.MIN_VALUE
    }

    val qualityScore = voice.quality * 10
    val latencyPenalty = voice.latency
    val localEngineBonus = if (voice.isNetworkConnectionRequired) 0 else 5

    return localeScore + qualityScore + localEngineBonus - latencyPenalty
  }

  private fun createVoicesArray(voices: Set<Voice>?): WritableArray {
    val array = Arguments.createArray()
    voices
      ?.sortedWith(compareBy<Voice>({ it.locale?.toLanguageTag() ?: "" }, { it.name }))
      ?.forEach { voice ->
        val map = Arguments.createMap()
        map.putString("name", voice.name)
        map.putString("locale", voice.locale?.toLanguageTag())
        map.putInt("quality", voice.quality)
        map.putInt("latency", voice.latency)
        map.putBoolean("networkRequired", voice.isNetworkConnectionRequired)

        val featuresArray = Arguments.createArray()
        voice.features?.sorted()?.forEach { feature ->
          featuresArray.pushString(feature)
        }
        map.putArray("features", featuresArray)

        array.pushMap(map)
      }
    return array
  }

  private fun annotateForSpeech(text: String): CharSequence {
    if (text.isEmpty()) {
      return text
    }

    val spannable = SpannableString(text)
    applyTelephoneSpans(spannable)
    applyVerbatimSpans(spannable, Patterns.EMAIL_ADDRESS)
    applyVerbatimSpans(spannable, Patterns.WEB_URL)
    return spannable
  }

  private fun applyTelephoneSpans(text: SpannableString) {
    val matcher = Patterns.PHONE.matcher(text)
    while (matcher.find()) {
      val start = matcher.start()
      val end = matcher.end()
      val raw = text.subSequence(start, end).toString().trim()
      val speakable = raw.filter { it.isDigit() || it == '+' || it == '*' || it == '#' }
      if (speakable.isNotBlank()) {
        text.setSpan(
          TtsSpan.TelephoneBuilder(speakable).build(),
          start,
          end,
          Spanned.SPAN_EXCLUSIVE_EXCLUSIVE,
        )
      }
    }
  }

  private fun applyVerbatimSpans(text: SpannableString, pattern: Pattern) {
    val matcher = pattern.matcher(text)
    while (matcher.find()) {
      val start = matcher.start()
      val end = matcher.end()
      val raw = text.subSequence(start, end).toString().trim()
      if (raw.isNotBlank()) {
        text.setSpan(
          TtsSpan.VerbatimBuilder(raw).build(),
          start,
          end,
          Spanned.SPAN_EXCLUSIVE_EXCLUSIVE,
        )
      }
    }
  }

  private fun normalizeLanguageTag(language: String): String {
    return language
      .trim()
      .replace('_', '-')
      .lowercase(Locale.US)
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

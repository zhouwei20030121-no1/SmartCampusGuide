package com.swu.smart_campus_guide

import android.os.Bundle
import android.speech.tts.TextToSpeech
import android.media.AudioManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.Locale

class MainActivity : FlutterActivity(), TextToSpeech.OnInitListener {
    private val ttsChannel = "smart_campus_guide/tts"
    private var tts: TextToSpeech? = null
    private var ttsReady = false
    private var ttsStatusMessage = "TTS is initializing"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        tts = TextToSpeech(this, this)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ttsChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "speak" -> {
                        result.success(
                            speak(
                                call.argument<String>("text").orEmpty(),
                                call.argument<String>("voice").orEmpty(),
                                call.argument<String>("language").orEmpty(),
                            )
                        )
                    }
                    "stop" -> {
                        tts?.stop()
                        result.success(mapOf("ok" to true))
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onInit(status: Int) {
        if (status == TextToSpeech.SUCCESS) {
            val languageStatus = chooseBestLanguage()
            ttsReady = languageStatus >= TextToSpeech.LANG_AVAILABLE
            ttsStatusMessage = if (ttsReady) {
                "TTS ready"
            } else {
                "Current emulator has no supported TTS language data"
            }
            tts?.setSpeechRate(0.86f)
            tts?.setPitch(1.04f)
        } else {
            ttsReady = false
            ttsStatusMessage = "TTS engine initialization failed"
        }
    }

    private fun chooseBestLanguage(): Int {
        val engine = tts ?: return TextToSpeech.ERROR
        val candidates = listOf(
            Locale.SIMPLIFIED_CHINESE,
            Locale.CHINA,
            Locale.CHINESE,
            Locale.getDefault(),
        )

        for (locale in candidates) {
            val status = engine.setLanguage(locale)
            if (status >= TextToSpeech.LANG_AVAILABLE) {
                return status
            }
        }
        return TextToSpeech.LANG_MISSING_DATA
    }

    private fun speak(text: String, voice: String, language: String): Map<String, Any> {
        if (text.isBlank()) {
            return mapOf("ok" to false, "reason" to "\u8BB2\u89E3\u8BCD\u4E3A\u7A7A")
        }
        if (!ttsReady) {
            return mapOf("ok" to false, "reason" to ttsStatusMessage)
        }

        val languageStatus = chooseLanguageFor(language)
        if (languageStatus < TextToSpeech.LANG_AVAILABLE) {
            return mapOf("ok" to false, "reason" to "Current emulator has no TTS data for $language")
        }
        applyVoiceProfile(voice)
        val chunks = splitForSpeech(normalizeForSpeech(text))
        if (chunks.isEmpty()) {
            return mapOf("ok" to false, "reason" to "\u8BB2\u89E3\u8BCD\u4E3A\u7A7A")
        }

        val params = Bundle().apply {
            putString(TextToSpeech.Engine.KEY_PARAM_STREAM, AudioManager.STREAM_MUSIC.toString())
        }
        var ok = true
        tts?.stop()
        chunks.forEachIndexed { index, chunk ->
            val queueMode = if (index == 0) TextToSpeech.QUEUE_FLUSH else TextToSpeech.QUEUE_ADD
            val speakResult = tts?.speak(
                chunk,
                queueMode,
                params,
                "guide_${System.currentTimeMillis()}_$index",
            )
            if (speakResult != TextToSpeech.SUCCESS) {
                ok = false
            }

            if (index < chunks.lastIndex) {
                val pauseMillis = pauseAfter(chunk)
                tts?.playSilentUtterance(
                    pauseMillis,
                    TextToSpeech.QUEUE_ADD,
                    "guide_pause_${System.currentTimeMillis()}_$index",
                )
            }
        }

        return if (ok) {
            mapOf("ok" to true)
        } else {
            mapOf("ok" to false, "reason" to "TTS speak() returned error")
        }
    }

    private fun chooseLanguageFor(language: String): Int {
        val engine = tts ?: return TextToSpeech.ERROR
        val normalized = language.lowercase(Locale.ROOT)
        val candidates = if (normalized.startsWith("en")) {
            listOf(Locale.US, Locale.UK, Locale.ENGLISH, Locale.getDefault())
        } else {
            listOf(Locale.SIMPLIFIED_CHINESE, Locale.CHINA, Locale.CHINESE, Locale.getDefault())
        }
        for (locale in candidates) {
            val status = engine.setLanguage(locale)
            if (status >= TextToSpeech.LANG_AVAILABLE) {
                return status
            }
        }
        return TextToSpeech.LANG_MISSING_DATA
    }

    private fun applyVoiceProfile(voice: String) {
        when (voice) {
            "young_male" -> {
                tts?.setSpeechRate(0.88f)
                tts?.setPitch(0.92f)
            }
            "young_female" -> {
                tts?.setSpeechRate(0.86f)
                tts?.setPitch(1.06f)
            }
            else -> {
                tts?.setSpeechRate(0.82f)
                tts?.setPitch(1.02f)
            }
        }
    }

    private fun normalizeForSpeech(text: String): String {
        return text
            .replace(Regex("[#*_`>\\-]+"), "")
            .replace("AI", "A I")
            .replace("TTS", "\u8BED\u97F3")
            .replace(Regex("\\s+"), " ")
            .trim()
    }

    private fun splitForSpeech(text: String): List<String> {
        val chunks = mutableListOf<String>()
        val current = StringBuilder()
        val softStops = setOf('\uFF0C', ',', '\u3001')
        val hardStops = setOf('\u3002', '\uFF01', '\uFF1F', '\uFF1B', '.', '!', '?', ';')

        for (char in text) {
            current.append(char)
            val shouldCut =
                char in hardStops ||
                    (char in softStops && current.length >= 38) ||
                    current.length >= 76

            if (shouldCut) {
                val chunk = current.toString().trim()
                if (chunk.isNotEmpty()) {
                    chunks.add(chunk)
                }
                current.clear()
            }
        }

        val tail = current.toString().trim()
        if (tail.isNotEmpty()) {
            chunks.add(tail)
        }
        return chunks
    }

    private fun pauseAfter(chunk: String): Long {
        val last = chunk.lastOrNull()
        return when (last) {
            '\u3002', '\uFF01', '\uFF1F', '.', '!', '?' -> 360L
            '\uFF1B', ';' -> 300L
            else -> 180L
        }
    }

    override fun onDestroy() {
        tts?.stop()
        tts?.shutdown()
        super.onDestroy()
    }
}

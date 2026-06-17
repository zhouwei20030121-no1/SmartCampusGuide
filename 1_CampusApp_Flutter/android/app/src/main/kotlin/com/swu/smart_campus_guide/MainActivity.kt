package com.swu.smart_campus_guide

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.media.AudioManager
import android.os.Bundle
import android.speech.tts.TextToSpeech
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.Locale

class MainActivity : FlutterActivity(), TextToSpeech.OnInitListener {
    private val ttsChannel = "smart_campus_guide/tts"
    private val locationChannel = "smart_campus_guide/location"
    private val locationPermissionRequest = 9102
    private var tts: TextToSpeech? = null
    private var ttsReady = false
    private var ttsStatusMessage = "TTS is initializing"
    private var pendingLocationResult: MethodChannel.Result? = null

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

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, locationChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getCurrentLocation" -> getCurrentLocation(result)
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
            return mapOf("ok" to false, "reason" to "讲解词为空")
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
            return mapOf("ok" to false, "reason" to "讲解词为空")
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
                tts?.playSilentUtterance(
                    pauseAfter(chunk),
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
        } else if (normalized.startsWith("ja")) {
            listOf(Locale.JAPAN, Locale.JAPANESE, Locale.getDefault())
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
            .replace("TTS", "语音")
            .replace(Regex("\\s+"), " ")
            .trim()
    }

    private fun splitForSpeech(text: String): List<String> {
        val chunks = mutableListOf<String>()
        val current = StringBuilder()
        val softStops = setOf('，', ',', '、')
        val hardStops = setOf('。', '！', '？', '；', '.', '!', '?', ';')

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
            '。', '！', '？', '.', '!', '?' -> 360L
            '；', ';' -> 300L
            else -> 180L
        }
    }

    override fun onDestroy() {
        tts?.stop()
        tts?.shutdown()
        super.onDestroy()
    }

    private fun getCurrentLocation(result: MethodChannel.Result) {
        if (!hasLocationPermission()) {
            pendingLocationResult = result
            requestPermissions(
                arrayOf(
                    Manifest.permission.ACCESS_FINE_LOCATION,
                    Manifest.permission.ACCESS_COARSE_LOCATION,
                ),
                locationPermissionRequest,
            )
            return
        }
        readLocation(result)
    }

    private fun hasLocationPermission(): Boolean {
        return checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED ||
            checkSelfPermission(Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED
    }

    private fun readLocation(result: MethodChannel.Result) {
        val manager = getSystemService(Context.LOCATION_SERVICE) as LocationManager
        val providers = listOf(
            LocationManager.GPS_PROVIDER,
            LocationManager.NETWORK_PROVIDER,
            LocationManager.PASSIVE_PROVIDER,
        ).filter { provider ->
            try {
                manager.isProviderEnabled(provider)
            } catch (_: Exception) {
                false
            }
        }

        if (providers.isEmpty()) {
            result.success(mapOf("ok" to false, "reason" to "系统定位服务未开启"))
            return
        }

        val cached = providers.mapNotNull { provider ->
            try {
                manager.getLastKnownLocation(provider)
            } catch (_: SecurityException) {
                null
            }
        }.maxByOrNull { it.time }

        if (cached != null && cached.latitude != 0.0 && cached.longitude != 0.0) {
            result.success(locationPayload(cached))
            return
        }

        val provider = providers.first()
        try {
            val listener = object : LocationListener {
                override fun onLocationChanged(location: Location) {
                    manager.removeUpdates(this)
                    result.success(locationPayload(location))
                }

                override fun onProviderDisabled(provider: String) {}
                override fun onProviderEnabled(provider: String) {}
            }
            manager.requestSingleUpdate(provider, listener, mainLooper)
        } catch (e: SecurityException) {
            result.success(mapOf("ok" to false, "reason" to "定位权限未开启"))
        } catch (e: Exception) {
            result.success(mapOf("ok" to false, "reason" to "定位失败：${e.message ?: "unknown"}"))
        }
    }

    private fun locationPayload(location: Location): Map<String, Any> {
        return mapOf(
            "ok" to true,
            "latitude" to location.latitude,
            "longitude" to location.longitude,
            "accuracy" to location.accuracy,
            "timestamp" to location.time / 1000.0,
        )
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != locationPermissionRequest) return
        val result = pendingLocationResult ?: return
        pendingLocationResult = null
        if (grantResults.any { it == PackageManager.PERMISSION_GRANTED }) {
            readLocation(result)
        } else {
            result.success(mapOf("ok" to false, "reason" to "定位权限未开启"))
        }
    }
}

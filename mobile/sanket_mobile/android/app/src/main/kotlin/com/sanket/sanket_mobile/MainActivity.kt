package com.sanket.sanket_mobile

import android.Manifest
import android.content.pm.PackageManager
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import kotlin.math.abs
import kotlin.math.log10
import kotlin.math.max
import kotlin.math.sqrt

/**
 * Hosts the microphone level stream used for audio timing.
 *
 * Only loudness summaries (RMS and peak dBFS per 100 ms window) leave this class.
 * Raw PCM is read into a reused buffer and never stored, written or transmitted.
 */
class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "sanket/audio_level")
            .setStreamHandler(AudioLevelStream(this))
    }
}

private class AudioLevelStream(private val activity: FlutterActivity) : EventChannel.StreamHandler {
    private val main = Handler(Looper.getMainLooper())
    @Volatile private var running = false
    private var worker: Thread? = null

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        if (activity.checkSelfPermission(Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
            events.error("permission", "Microphone permission not granted", null)
            return
        }
        val rate = 16000
        val window = rate / 10
        val minBuffer = AudioRecord.getMinBufferSize(rate, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT)
        val recorder = try {
            AudioRecord(MediaRecorder.AudioSource.MIC, rate, AudioFormat.CHANNEL_IN_MONO,
                AudioFormat.ENCODING_PCM_16BIT, max(minBuffer, window * 2))
        } catch (e: Exception) {
            events.error("unavailable", e.message ?: "Microphone unavailable", null)
            return
        }
        if (recorder.state != AudioRecord.STATE_INITIALIZED) {
            recorder.release()
            events.error("unavailable", "Microphone could not be initialised", null)
            return
        }
        running = true
        worker = Thread {
            val buffer = ShortArray(window)
            try {
                recorder.startRecording()
                while (running) {
                    val read = recorder.read(buffer, 0, window)
                    if (read <= 0) continue
                    var sum = 0.0
                    var peak = 0
                    for (i in 0 until read) {
                        val v = buffer[i].toInt()
                        sum += (v * v).toDouble()
                        peak = max(peak, abs(v))
                    }
                    val rms = sqrt(sum / read) / 32768.0
                    val level = mapOf(
                        "t" to SystemClock.elapsedRealtime(),
                        "rmsDb" to 20 * log10(max(rms, 1e-5)),
                        "peakDb" to 20 * log10(max(peak / 32768.0, 1e-5))
                    )
                    buffer.fill(0)
                    main.post { if (running) events.success(level) }
                }
            } catch (e: Exception) {
                main.post { events.error("stream", e.message ?: "Microphone stream failed", null) }
            } finally {
                try { recorder.stop() } catch (_: Exception) {}
                recorder.release()
            }
        }.also { it.start() }
    }

    override fun onCancel(arguments: Any?) {
        running = false
        worker = null
    }
}

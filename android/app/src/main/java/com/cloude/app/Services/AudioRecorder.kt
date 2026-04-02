package com.cloude.app.Services

import android.annotation.SuppressLint
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.util.Base64
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import java.io.ByteArrayOutputStream
import kotlin.math.log10
import kotlin.math.sqrt

class AudioRecorder {
    private var audioRecord: AudioRecord? = null
    private var recordingThread: Thread? = null
    private var pcmOutput: ByteArrayOutputStream? = null

    private val _isRecording = MutableStateFlow(false)
    val isRecording: StateFlow<Boolean> = _isRecording

    private val _audioLevel = MutableStateFlow(0f)
    val audioLevel: StateFlow<Float> = _audioLevel

    @SuppressLint("MissingPermission")
    fun startRecording(): Boolean {
        val bufferSize = AudioRecord.getMinBufferSize(SAMPLE_RATE, CHANNEL_CONFIG, AUDIO_FORMAT)
        if (bufferSize <= 0) return false

        val recorder = AudioRecord(
            MediaRecorder.AudioSource.MIC,
            SAMPLE_RATE,
            CHANNEL_CONFIG,
            AUDIO_FORMAT,
            bufferSize
        )
        if (recorder.state != AudioRecord.STATE_INITIALIZED) {
            recorder.release()
            return false
        }

        pcmOutput = ByteArrayOutputStream()
        audioRecord = recorder
        recorder.startRecording()
        _isRecording.value = true

        recordingThread = Thread {
            val buffer = ShortArray(bufferSize / 2)
            while (_isRecording.value) {
                val read = recorder.read(buffer, 0, buffer.size)
                if (read > 0) {
                    val bytes = ByteArray(read * 2)
                    for (i in 0 until read) {
                        bytes[i * 2] = (buffer[i].toInt() and 0xFF).toByte()
                        bytes[i * 2 + 1] = (buffer[i].toInt() shr 8 and 0xFF).toByte()
                    }
                    pcmOutput?.write(bytes)

                    var sum = 0L
                    for (i in 0 until read) sum += buffer[i] * buffer[i]
                    val rms = sqrt(sum.toDouble() / read)
                    val db = 20 * log10(rms + 1)
                    _audioLevel.value = (db / 90.0).coerceIn(0.0, 1.0).toFloat()
                }
            }
        }
        recordingThread?.start()
        return true
    }

    fun stopRecording(): String? {
        _isRecording.value = false
        recordingThread?.join(1000)
        recordingThread = null

        audioRecord?.stop()
        audioRecord?.release()
        audioRecord = null

        val pcm = pcmOutput?.toByteArray() ?: return null
        pcmOutput = null
        _audioLevel.value = 0f

        if (pcm.isEmpty()) return null
        return Base64.encodeToString(wrapWav(pcm), Base64.NO_WRAP)
    }

    fun cancelRecording() {
        _isRecording.value = false
        recordingThread?.join(1000)
        recordingThread = null
        audioRecord?.stop()
        audioRecord?.release()
        audioRecord = null
        pcmOutput = null
        _audioLevel.value = 0f
    }

    fun release() {
        if (_isRecording.value) {
            _isRecording.value = false
            recordingThread?.join(1000)
        }
        audioRecord?.release()
        audioRecord = null
        pcmOutput = null
    }

    private fun wrapWav(pcm: ByteArray): ByteArray {
        val byteRate = SAMPLE_RATE * CHANNELS * BITS_PER_SAMPLE / 8
        val blockAlign = CHANNELS * BITS_PER_SAMPLE / 8
        val header = ByteArray(44)

        fun putInt(offset: Int, value: Int) {
            header[offset] = (value and 0xFF).toByte()
            header[offset + 1] = (value shr 8 and 0xFF).toByte()
            header[offset + 2] = (value shr 16 and 0xFF).toByte()
            header[offset + 3] = (value shr 24 and 0xFF).toByte()
        }

        fun putShort(offset: Int, value: Int) {
            header[offset] = (value and 0xFF).toByte()
            header[offset + 1] = (value shr 8 and 0xFF).toByte()
        }

        "RIFF".toByteArray().copyInto(header, 0)
        putInt(4, 36 + pcm.size)
        "WAVE".toByteArray().copyInto(header, 8)
        "fmt ".toByteArray().copyInto(header, 12)
        putInt(16, 16)
        putShort(20, 1)
        putShort(22, CHANNELS)
        putInt(24, SAMPLE_RATE)
        putInt(28, byteRate)
        putShort(32, blockAlign)
        putShort(34, BITS_PER_SAMPLE)
        "data".toByteArray().copyInto(header, 36)
        putInt(40, pcm.size)

        return header + pcm
    }

    companion object {
        private const val SAMPLE_RATE = 16000
        private const val CHANNELS = 1
        private const val BITS_PER_SAMPLE = 16
        private const val CHANNEL_CONFIG = AudioFormat.CHANNEL_IN_MONO
        private const val AUDIO_FORMAT = AudioFormat.ENCODING_PCM_16BIT
    }
}

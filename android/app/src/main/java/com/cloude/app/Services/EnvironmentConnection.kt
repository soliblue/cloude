package com.cloude.app.Services

import android.os.Handler
import android.os.Looper
import android.util.Base64
import android.util.Log
import com.cloude.app.Models.AgentState
import com.cloude.app.Models.ClientMessage
import com.cloude.app.Models.ServerMessage
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.Response
import okhttp3.WebSocket
import okhttp3.WebSocketListener
import java.util.concurrent.TimeUnit

class EnvironmentConnection(
    val environmentId: String,
    private val appContext: android.content.Context? = null,
    private val onMessage: (ServerMessage) -> Unit
) {
    private var wasRunning = false
    private var webSocket: WebSocket? = null
    private var savedHost = ""
    private var savedPort = 0
    private var savedToken = ""
    private val client = OkHttpClient.Builder()
        .readTimeout(0, TimeUnit.MILLISECONDS)
        .build()

    private val handler = Handler(Looper.getMainLooper())
    private var reconnectAttempt = 0
    private var reconnectRunnable: Runnable? = null
    private var intentionalDisconnect = false

    private val _isConnected = MutableStateFlow(false)
    val isConnected: StateFlow<Boolean> = _isConnected

    private val _isAuthenticated = MutableStateFlow(false)
    val isAuthenticated: StateFlow<Boolean> = _isAuthenticated

    private val _agentState = MutableStateFlow(AgentState.idle)
    val agentState: StateFlow<AgentState> = _agentState

    private val _lastError = MutableStateFlow<String?>(null)
    val lastError: StateFlow<String?> = _lastError

    private val _defaultWorkingDirectory = MutableStateFlow<String?>(null)
    val defaultWorkingDirectory: StateFlow<String?> = _defaultWorkingDirectory

    private val _skills = MutableStateFlow<List<com.cloude.app.Models.Skill>>(emptyList())
    val skills: StateFlow<List<com.cloude.app.Models.Skill>> = _skills

    private val _whisperReady = MutableStateFlow(false)
    val whisperReady: StateFlow<Boolean> = _whisperReady

    private data class PendingChunks(
        val chunks: MutableMap<Int, String>,
        val totalChunks: Int,
        val mimeType: String,
        val size: Long
    )
    private val pendingChunks = mutableMapOf<String, PendingChunks>()

    fun connect(host: String, port: Int, token: String) {
        savedHost = host
        savedPort = port
        savedToken = token
        intentionalDisconnect = false
        reconnectAttempt = 0
        reconnect()
    }

    fun reconnect() {
        if (savedHost.isEmpty()) return
        cancelPendingReconnect()
        disconnect(clearCredentials = false, intentional = false)

        val isIP = savedHost.all { it.isDigit() || it == '.' || it == ':' }
        val scheme = if (isIP) "ws" else "wss"
        val url = "$scheme://$savedHost:$savedPort"

        Log.d("Cloude", "WS connecting to $url (attempt=$reconnectAttempt)")
        val request = Request.Builder().url(url).build()

        webSocket = client.newWebSocket(request, object : WebSocketListener() {
            override fun onOpen(webSocket: WebSocket, response: Response) {
                Log.d("Cloude", "WS connected")
                _isConnected.value = true
                _lastError.value = null
                reconnectAttempt = 0
                send(ClientMessage.Auth(savedToken))
            }

            override fun onMessage(webSocket: WebSocket, text: String) {
                Log.d("Cloude", "WS raw: ${text.take(200)}")
                val message = ServerMessage.decode(text)
                if (message == null) {
                    Log.w("Cloude", "WS decode failed: ${text.take(300)}")
                    return
                }
                Log.d("Cloude", "WS decoded: ${message::class.simpleName}")

                when (message) {
                    is ServerMessage.AuthRequired -> send(ClientMessage.Auth(savedToken))
                    is ServerMessage.AuthResult -> {
                        _isAuthenticated.value = message.success
                        if (!message.success) _lastError.value = message.message ?: "Auth failed"
                    }
                    is ServerMessage.Status -> {
                        val prev = wasRunning
                        _agentState.value = message.state
                        wasRunning = message.state != AgentState.idle
                        if (prev && !wasRunning && appContext != null) {
                            CloudeNotificationManager.notifyAgentComplete(appContext, "Agent finished")
                        }
                    }
                    is ServerMessage.DefaultWorkingDirectory -> _defaultWorkingDirectory.value = message.path
                    is ServerMessage.Skills -> _skills.value = message.skills
                    is ServerMessage.WhisperReady -> _whisperReady.value = message.ready
                    is ServerMessage.FileChunk -> {
                        val pending = pendingChunks.getOrPut(message.path) {
                            PendingChunks(mutableMapOf(), message.totalChunks, message.mimeType, message.size)
                        }
                        pending.chunks[message.chunkIndex] = message.data
                        Log.d("Cloude", "FileChunk ${pending.chunks.size}/${pending.totalChunks} for ${message.path}")
                        onMessage(message)
                        if (pending.chunks.size == pending.totalChunks) {
                            val decodedChunks = (0 until pending.totalChunks).map { i ->
                                Base64.decode(pending.chunks[i]!!, Base64.DEFAULT)
                            }
                            val totalSize = decodedChunks.sumOf { it.size }
                            val combined = ByteArray(totalSize)
                            var offset = 0
                            for (chunk in decodedChunks) {
                                System.arraycopy(chunk, 0, combined, offset, chunk.size)
                                offset += chunk.size
                            }
                            pendingChunks.remove(message.path)
                            val combinedBase64 = Base64.encodeToString(combined, Base64.NO_WRAP)
                            val synthetic = ServerMessage.FileContent(
                                path = message.path,
                                data = combinedBase64,
                                mimeType = pending.mimeType,
                                size = pending.size,
                                truncated = false
                            )
                            Log.d("Cloude", "Chunks reassembled for ${message.path} (${combined.size} bytes)")
                            onMessage(synthetic)
                        }
                        return
                    }
                    else -> {}
                }

                onMessage(message)
            }

            override fun onFailure(webSocket: WebSocket, t: Throwable, response: Response?) {
                Log.w("Cloude", "WS failure: ${t.message}")
                _lastError.value = t.message
                handleDisconnect()
                scheduleReconnect()
            }

            override fun onClosed(webSocket: WebSocket, code: Int, reason: String) {
                Log.d("Cloude", "WS closed: code=$code reason=$reason")
                handleDisconnect()
                scheduleReconnect()
            }
        })
    }

    fun disconnect(clearCredentials: Boolean = true, intentional: Boolean = true) {
        intentionalDisconnect = intentional
        cancelPendingReconnect()
        webSocket?.close(1000, null)
        webSocket = null
        _isConnected.value = false
        _isAuthenticated.value = false
        _agentState.value = AgentState.idle
        if (clearCredentials) {
            savedHost = ""
            savedToken = ""
        }
    }

    fun send(message: ClientMessage) {
        val json = message.toJson()
        Log.d("Cloude", "WS send: ${json.take(300)}")
        val sent = webSocket?.send(json) ?: false
        if (!sent) {
            Log.w("Cloude", "WS send failed, connection dead")
            scheduleReconnect()
        }
    }

    private fun handleDisconnect() {
        _isConnected.value = false
        _isAuthenticated.value = false
        _agentState.value = AgentState.idle
    }

    private fun scheduleReconnect() {
        if (intentionalDisconnect || savedHost.isEmpty()) return
        cancelPendingReconnect()

        val delayMs = minOf(1000L * (1L shl minOf(reconnectAttempt, 5)), 30_000L)
        reconnectAttempt++
        Log.d("Cloude", "WS scheduling reconnect in ${delayMs}ms (attempt=$reconnectAttempt)")

        reconnectRunnable = Runnable { reconnect() }
        handler.postDelayed(reconnectRunnable!!, delayMs)
    }

    private fun cancelPendingReconnect() {
        reconnectRunnable?.let { handler.removeCallbacks(it) }
        reconnectRunnable = null
    }
}

package com.cloude.app.Services

import com.cloude.app.Models.AgentState
import com.cloude.app.Models.ClientMessage
import com.cloude.app.Models.ServerEnvironment
import com.cloude.app.Models.ServerMessage
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.StateFlow

class ConnectionManager(private val appContext: android.content.Context? = null) {
    private val connections = mutableMapOf<String, EnvironmentConnection>()
    private val conversationOutputs = mutableMapOf<String, ConversationOutput>()
    private val conversationEnvironments = mutableMapOf<String, String>()

    private val _isConnected = MutableStateFlow(false)
    val isConnected: StateFlow<Boolean> = _isConnected

    private val _isAuthenticated = MutableStateFlow(false)
    val isAuthenticated: StateFlow<Boolean> = _isAuthenticated

    private val _agentState = MutableStateFlow(AgentState.idle)
    val agentState: StateFlow<AgentState> = _agentState

    private val _events = MutableSharedFlow<ServerMessage>(extraBufferCapacity = 64)
    val events: SharedFlow<ServerMessage> = _events

    val isAnyRunning: Boolean
        get() = conversationOutputs.values.any { it.isRunning.value }

    fun output(conversationId: String): ConversationOutput =
        conversationOutputs.getOrPut(conversationId) { ConversationOutput() }

    fun registerConversation(conversationId: String, environmentId: String) {
        conversationEnvironments[conversationId] = environmentId
    }

    fun connectionForConversation(conversationId: String): EnvironmentConnection? =
        conversationEnvironments[conversationId]?.let { connections[it] }

    fun connection(forId: String): EnvironmentConnection? = connections[forId]

    fun connectEnvironment(env: ServerEnvironment) {
        val existing = connections[env.id]
        if (existing != null) {
            existing.disconnect()
        }

        val conn = EnvironmentConnection(env.id, appContext) { message ->
            _events.tryEmit(message)
            updateAggregateState()
        }
        connections[env.id] = conn
        conn.connect(env.host, env.port, env.token)
        updateAggregateState()
    }

    fun disconnectEnvironment(envId: String) {
        connections.remove(envId)?.disconnect()
        updateAggregateState()
    }

    fun disconnectAll() {
        connections.values.forEach { it.disconnect() }
        connections.clear()
        updateAggregateState()
    }

    fun reconnectAll() {
        connections.values.forEach { it.reconnect() }
    }

    fun send(message: ClientMessage, environmentId: String) {
        val conn = connections[environmentId]
        if (conn == null) {
            android.util.Log.e("Cloude", "No connection for envId=$environmentId, available=${connections.keys}")
            return
        }
        conn.send(message)
    }

    private fun updateAggregateState() {
        _isConnected.value = connections.values.any { it.isConnected.value }
        _isAuthenticated.value = connections.values.any { it.isAuthenticated.value }
        _agentState.value = connections.values
            .map { it.agentState.value }
            .firstOrNull { it != AgentState.idle }
            ?: AgentState.idle
    }
}

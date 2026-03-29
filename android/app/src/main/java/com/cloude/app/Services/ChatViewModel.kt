package com.cloude.app.Services

import android.util.Log
import com.cloude.app.Models.AgentState
import com.cloude.app.Models.AttachedFilePayload
import com.cloude.app.Models.ChatMessage
import com.cloude.app.Models.ClientMessage
import com.cloude.app.Models.Conversation
import com.cloude.app.Models.ConversationStore
import com.cloude.app.Models.EnvironmentStore
import com.cloude.app.Models.ServerMessage
import com.cloude.app.Models.ToolCall
import com.cloude.app.Models.ToolCallState
import com.cloude.app.Models.UsageStats
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch

class ChatViewModel(
    private val connectionManager: ConnectionManager,
    private val environmentStore: EnvironmentStore,
    private val conversationStore: ConversationStore
) {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)

    private val _conversation = MutableStateFlow(Conversation())
    val conversation: StateFlow<Conversation> = _conversation

    val output = ConversationOutput()

    private val _isTranscribing = MutableStateFlow(false)
    val isTranscribing: StateFlow<Boolean> = _isTranscribing

    private val _pendingTranscription = MutableStateFlow<String?>(null)
    val pendingTranscription: StateFlow<String?> = _pendingTranscription

    private val _usageStats = MutableStateFlow<UsageStats?>(null)
    val usageStats: StateFlow<UsageStats?> = _usageStats

    private var awaitingUsageStats = false

    private val activeEnvId: String?
        get() = _conversation.value.environmentId ?: environmentStore.activeEnvironmentId.value

    fun init() {
        scope.launch {
            connectionManager.events.collect { message ->
                Log.d("Cloude", "VM handleMessage: ${message::class.simpleName}")
                handleMessage(message)
            }
        }
    }

    fun loadConversation(id: String) {
        conversationStore.conversation(id)?.let { _conversation.value = it }
    }

    fun newConversation() {
        _conversation.value = Conversation(
            environmentId = environmentStore.activeEnvironmentId.value
        )
    }

    fun sendMessage(text: String, imagesBase64: List<String>? = null, filesBase64: List<AttachedFilePayload>? = null) {
        val envId = activeEnvId
        Log.d("Cloude", "sendMessage: envId=$envId sessionId=${_conversation.value.sessionId} isRunning=${output.isRunning.value} images=${imagesBase64?.size ?: 0} files=${filesBase64?.size ?: 0}")
        if (envId == null) return
        val conv = _conversation.value

        val userMessage = ChatMessage(isUser = true, text = text, imageCount = imagesBase64?.size ?: 0, fileCount = filesBase64?.size ?: 0)
        val newMessages = conv.messages.toMutableList().apply { add(userMessage) }
        _conversation.value = conv.copy(
            messages = newMessages,
            lastMessageAt = System.currentTimeMillis()
        )
        persistConversation()

        output.reset()
        output.setRunning(true)

        val workingDir = conv.workingDirectory
            ?: connectionManager.connection(envId)?.defaultWorkingDirectory?.value

        connectionManager.send(
            ClientMessage.Chat(
                message = text,
                workingDirectory = workingDir,
                sessionId = conv.sessionId,
                isNewSession = conv.sessionId == null,
                conversationId = conv.id,
                conversationName = conv.name,
                imagesBase64 = imagesBase64,
                filesBase64 = filesBase64,
                effort = conv.defaultEffort,
                model = conv.defaultModel
            ),
            envId
        )
    }

    fun transcribe(audioBase64: String) {
        val envId = activeEnvId ?: return
        _isTranscribing.value = true
        connectionManager.send(ClientMessage.Transcribe(audioBase64), envId)
    }

    fun consumeTranscription() {
        _pendingTranscription.value = null
    }

    fun abort() {
        val envId = activeEnvId ?: return
        Log.d("Cloude", "abort called")
        connectionManager.send(ClientMessage.Abort(conversationId = _conversation.value.id), envId)
        output.setRunning(false)
        output.setCompacting(false)
    }

    fun setEnvironmentId(envId: String) {
        _conversation.value = _conversation.value.copy(environmentId = envId)
    }

    fun setEffort(effort: String?) {
        _conversation.value = _conversation.value.copy(defaultEffort = effort)
        persistConversation()
    }

    fun setModel(model: String?) {
        _conversation.value = _conversation.value.copy(defaultModel = model)
        persistConversation()
    }

    fun setWorkingDirectory(path: String) {
        _conversation.value = _conversation.value.copy(workingDirectory = path)
        persistConversation()
    }

    fun requestUsageStats() {
        val envId = activeEnvId ?: return
        awaitingUsageStats = true
        connectionManager.send(ClientMessage.GetUsageStats, envId)
    }

    fun dismissUsageStats() {
        _usageStats.value = null
    }

    fun toggleCollapse(messageId: String) {
        val conv = _conversation.value
        val updated = conv.messages.map {
            if (it.id == messageId) it.copy(isCollapsed = !it.isCollapsed) else it
        }
        _conversation.value = conv.copy(messages = updated.toMutableList())
    }

    private fun handleMessage(message: ServerMessage) {
        when (message) {
            is ServerMessage.Output -> output.appendText(message.text)

            is ServerMessage.Status -> {
                Log.d("Cloude", "VM Status: ${message.state}")
                when (message.state) {
                    AgentState.running -> {
                        output.setRunning(true)
                        output.setCompacting(false)
                    }
                    AgentState.compacting -> {
                        output.setCompacting(true)
                        output.setRunning(true)
                    }
                    AgentState.idle -> finalizeAssistantMessage()
                }
            }

            is ServerMessage.ToolCall -> {
                output.addToolCall(
                    ToolCall(
                        name = message.name,
                        input = message.input,
                        toolId = message.toolId,
                        parentToolId = message.parentToolId,
                        textPosition = message.textPosition,
                        state = ToolCallState.executing,
                        editInfo = message.editInfo
                    )
                )
            }

            is ServerMessage.ToolResult -> {
                output.updateToolResult(message.toolId, message.summary, message.output)
            }

            is ServerMessage.SessionId -> {
                output.newSessionId = message.id
                _conversation.value = _conversation.value.copy(sessionId = message.id)
                persistConversation()
            }

            is ServerMessage.RunStats -> {
                output.runStats = Triple(message.durationMs, message.costUsd, message.model)
            }

            is ServerMessage.MessageUUID -> {
                output.messageUUID = message.uuid
            }

            is ServerMessage.Transcription -> {
                _pendingTranscription.value = message.text
                _isTranscribing.value = false
            }

            is ServerMessage.UsageStatsMsg -> {
                if (awaitingUsageStats) {
                    awaitingUsageStats = false
                    _usageStats.value = message.stats
                }
            }

            is ServerMessage.Error -> {
                output.appendText("\n**Error:** ${message.message}")
                finalizeAssistantMessage()
            }

            else -> {}
        }
    }

    private fun finalizeAssistantMessage() {
        Log.d("Cloude", "finalizeAssistantMessage: fullText=${output.fullText.length} toolCalls=${output.toolCalls.value.size}")
        val text = output.fullText
        if (text.isEmpty() && output.toolCalls.value.isEmpty()) {
            output.setRunning(false)
            output.setCompacting(false)
            return
        }

        output.completeExecutingTools()
        val assistantMessage = ChatMessage(
            isUser = false,
            text = text,
            toolCalls = output.toolCalls.value.toMutableList(),
            durationMs = output.runStats?.first,
            costUsd = output.runStats?.second,
            serverUUID = output.messageUUID,
            model = output.runStats?.third
        )

        val conv = _conversation.value
        val newMessages = conv.messages.toMutableList().apply { add(assistantMessage) }
        _conversation.value = conv.copy(
            messages = newMessages,
            lastMessageAt = System.currentTimeMillis()
        )

        Log.d("Cloude", "finalizeAssistantMessage: done, isRunning will be false")
        persistConversation()
        output.reset()
    }

    private fun persistConversation() {
        val conv = _conversation.value
        if (!conv.isEmpty) conversationStore.save(conv)
    }
}

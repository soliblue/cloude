package com.cloude.app.Services

import android.util.Log
import com.cloude.app.Models.AgentState
import com.cloude.app.Models.ChatMessage
import com.cloude.app.Models.ClientMessage
import com.cloude.app.Models.Conversation
import com.cloude.app.Models.ConversationStore
import com.cloude.app.Models.EnvironmentStore
import com.cloude.app.Models.ServerMessage
import com.cloude.app.Models.ToolCall
import com.cloude.app.Models.ToolCallState
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

    fun sendMessage(text: String, imagesBase64: List<String>? = null) {
        val envId = activeEnvId
        Log.d("Cloude", "sendMessage: envId=$envId sessionId=${_conversation.value.sessionId} isRunning=${output.isRunning.value} images=${imagesBase64?.size ?: 0}")
        if (envId == null) return
        val conv = _conversation.value

        val userMessage = ChatMessage(isUser = true, text = text, imageCount = imagesBase64?.size ?: 0)
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
                effort = conv.defaultEffort,
                model = conv.defaultModel
            ),
            envId
        )
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

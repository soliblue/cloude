package com.cloude.app.Services

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.util.Base64
import android.util.Log
import com.cloude.app.Models.AgentState
import com.cloude.app.Models.MemorySection
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
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import java.io.File

sealed class DeviceAction {
    data class Haptic(val style: String) : DeviceAction()
    data class Notify(val message: String) : DeviceAction()
    data class Screenshot(val conversationId: String?) : DeviceAction()
}

class ChatViewModel(
    private val connectionManager: ConnectionManager,
    private val environmentStore: EnvironmentStore,
    private val conversationStore: ConversationStore
) {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)

    private val _conversation = MutableStateFlow(Conversation())
    val conversation: StateFlow<Conversation> = _conversation

    fun output(conversationId: String): ConversationOutput = connectionManager.output(conversationId)

    val activeOutput: ConversationOutput
        get() = connectionManager.output(_conversation.value.id)

    private val _isTranscribing = MutableStateFlow(false)
    val isTranscribing: StateFlow<Boolean> = _isTranscribing

    private val _pendingTranscription = MutableStateFlow<String?>(null)
    val pendingTranscription: StateFlow<String?> = _pendingTranscription

    private val _usageStats = MutableStateFlow<UsageStats?>(null)
    val usageStats: StateFlow<UsageStats?> = _usageStats

    private val _plans = MutableStateFlow<Map<String, List<com.cloude.app.Models.PlanItem>>?>(null)
    val plans: StateFlow<Map<String, List<com.cloude.app.Models.PlanItem>>?> = _plans

    private val _memorySections = MutableStateFlow<List<MemorySection>?>(null)
    val memorySections: StateFlow<List<MemorySection>?> = _memorySections

    private val _showSkills = MutableStateFlow(false)
    val showSkills: StateFlow<Boolean> = _showSkills

    private val _deviceActions = MutableSharedFlow<DeviceAction>(extraBufferCapacity = 8)
    val deviceActions: SharedFlow<DeviceAction> = _deviceActions

    private val deviceJson = Json { ignoreUnknownKeys = true; isLenient = true }

    private val _fileSearchResults = MutableStateFlow<List<String>>(emptyList())
    val fileSearchResults: StateFlow<List<String>> = _fileSearchResults
    private var pendingFileSearchQuery: String? = null

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
        Log.d("Cloude", "sendMessage: envId=$envId sessionId=${_conversation.value.sessionId} images=${imagesBase64?.size ?: 0} files=${filesBase64?.size ?: 0}")
        if (envId == null) return
        val conv = _conversation.value

        val messageId = java.util.UUID.randomUUID().toString()
        val thumbnails = imagesBase64?.map { base64 ->
            val bytes = Base64.decode(base64, Base64.DEFAULT)
            val original = BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
            val scale = minOf(150f / original.width, 150f / original.height, 1f)
            val thumb = if (scale < 1f) Bitmap.createScaledBitmap(original, (original.width * scale).toInt(), (original.height * scale).toInt(), true) else original
            val stream = java.io.ByteArrayOutputStream()
            thumb.compress(Bitmap.CompressFormat.JPEG, 70, stream)
            Base64.encodeToString(stream.toByteArray(), Base64.NO_WRAP)
        }
        val previewPaths = imagesBase64?.mapIndexed { index, base64 ->
            val file = File(conversationStore.imagesDir, "${messageId}_${index}.jpg")
            file.writeBytes(Base64.decode(base64, Base64.DEFAULT))
            file.absolutePath
        }
        val userMessage = ChatMessage(id = messageId, isUser = true, text = text, imageCount = imagesBase64?.size ?: 0, fileCount = filesBase64?.size ?: 0, imageThumbnails = thumbnails, imagePreviews = previewPaths)

        val isConnected = connectionManager.connection(envId)?.isAuthenticated?.value == true
        val isRunning = connectionManager.output(conv.id).isRunning.value

        if (!isConnected || isRunning) {
            Log.d("Cloude", "Queueing message: connected=$isConnected running=$isRunning")
            val queued = userMessage.copy(isQueued = true)
            val pending = conv.pendingMessages.toMutableList().apply { add(queued) }
            _conversation.value = conv.copy(
                pendingMessages = pending,
                lastMessageAt = System.currentTimeMillis()
            )
            persistConversation()
            return
        }

        val newMessages = conv.messages.toMutableList().apply { add(userMessage) }
        _conversation.value = conv.copy(
            messages = newMessages,
            lastMessageAt = System.currentTimeMillis()
        )
        persistConversation()

        connectionManager.registerConversation(conv.id, envId)
        val out = connectionManager.output(conv.id)
        out.reset()
        out.setRunning(true)

        val workingDir = conv.workingDirectory
            ?: connectionManager.connection(envId)?.defaultWorkingDirectory?.value
        val isNewSession = conv.sessionId == null
        val isFork = conv.pendingFork

        connectionManager.send(
            ClientMessage.Chat(
                message = text,
                workingDirectory = workingDir,
                sessionId = conv.sessionId,
                isNewSession = isNewSession,
                conversationId = conv.id,
                conversationName = conv.name,
                imagesBase64 = imagesBase64,
                filesBase64 = filesBase64,
                effort = conv.defaultEffort,
                model = conv.defaultModel,
                forkSession = isFork
            ),
            envId
        )

        if (isNewSession) {
            connectionManager.send(
                ClientMessage.SuggestName(text = text, context = emptyList(), conversationId = conv.id),
                envId
            )
        }

        if (isFork) {
            _conversation.value = _conversation.value.copy(pendingFork = false)
            persistConversation()
        }
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
        val convId = _conversation.value.id
        connectionManager.send(ClientMessage.Abort(conversationId = convId), envId)
        val out = connectionManager.output(convId)
        out.setRunning(false)
        out.setCompacting(false)
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

    fun requestPlans() {
        val envId = activeEnvId ?: return
        val workingDir = _conversation.value.workingDirectory
            ?: connectionManager.connection(envId)?.defaultWorkingDirectory?.value ?: return
        connectionManager.send(ClientMessage.GetPlans(workingDir), envId)
    }

    fun deletePlan(stage: String, filename: String) {
        val envId = activeEnvId ?: return
        val workingDir = _conversation.value.workingDirectory
            ?: connectionManager.connection(envId)?.defaultWorkingDirectory?.value ?: return
        connectionManager.send(ClientMessage.DeletePlan(stage, filename, workingDir), envId)
        val current = _plans.value?.toMutableMap() ?: return
        current[stage] = current[stage]?.filter { it.filename != filename } ?: emptyList()
        _plans.value = current
    }

    fun dismissPlans() {
        _plans.value = null
    }

    fun requestMemories() {
        val envId = activeEnvId ?: return
        val workingDir = _conversation.value.workingDirectory
            ?: connectionManager.connection(envId)?.defaultWorkingDirectory?.value ?: return
        connectionManager.send(ClientMessage.GetMemories(workingDir), envId)
    }

    fun dismissMemories() {
        _memorySections.value = null
    }

    fun showSkills() {
        _showSkills.value = true
    }

    fun dismissSkills() {
        _showSkills.value = false
    }

    fun renameConversation(name: String) {
        _conversation.value = _conversation.value.copy(name = name, userRenamed = true)
        persistConversation()
    }

    fun setSymbol(symbol: String?) {
        _conversation.value = _conversation.value.copy(symbol = symbol?.ifEmpty { null })
        persistConversation()
    }

    fun deleteQueuedMessage(messageId: String) {
        val conv = _conversation.value
        val pending = conv.pendingMessages.filter { it.id != messageId }.toMutableList()
        _conversation.value = conv.copy(pendingMessages = pending)
        persistConversation()
    }

    private fun flushPendingMessages() {
        val conv = _conversation.value
        if (conv.pendingMessages.isEmpty()) return
        val envId = activeEnvId ?: return
        val connection = connectionManager.connection(envId)
        if (connection?.isAuthenticated?.value != true) return
        if (connectionManager.output(conv.id).isRunning.value) return

        Log.d("Cloude", "Flushing ${conv.pendingMessages.size} pending messages")
        val pending = conv.pendingMessages.toList()
        val flushed = pending.map { it.copy(isQueued = false) }
        val newMessages = conv.messages.toMutableList().apply { addAll(flushed) }
        _conversation.value = conv.copy(
            messages = newMessages,
            pendingMessages = mutableListOf(),
            lastMessageAt = System.currentTimeMillis()
        )
        persistConversation()

        connectionManager.registerConversation(conv.id, envId)
        val out = connectionManager.output(conv.id)
        out.reset()
        out.setRunning(true)

        val combinedText = pending.joinToString("\n\n") { it.text }
        val workingDir = conv.workingDirectory
            ?: connection.defaultWorkingDirectory?.value
        val isNewSession = conv.sessionId == null

        connectionManager.send(
            ClientMessage.Chat(
                message = combinedText,
                workingDirectory = workingDir,
                sessionId = conv.sessionId,
                isNewSession = isNewSession,
                conversationId = conv.id,
                conversationName = conv.name,
                effort = conv.defaultEffort,
                model = conv.defaultModel
            ),
            envId
        )

        if (isNewSession) {
            connectionManager.send(
                ClientMessage.SuggestName(text = combinedText, context = emptyList(), conversationId = conv.id),
                envId
            )
        }
    }

    private fun flushAllPendingMessages() {
        val currentConvId = _conversation.value.id
        conversationStore.conversations.value
            .filter { it.pendingMessages.isNotEmpty() && it.id != currentConvId }
            .forEach { conv ->
                val envId = conv.environmentId ?: environmentStore.activeEnvironmentId.value ?: return@forEach
                val connection = connectionManager.connection(envId)
                if (connection?.isAuthenticated?.value != true) return@forEach
                if (connectionManager.output(conv.id).isRunning.value) return@forEach

                Log.d("Cloude", "Flushing ${conv.pendingMessages.size} pending messages for conv ${conv.id}")
                val pending = conv.pendingMessages.toList()
                val flushed = pending.map { it.copy(isQueued = false) }
                val newMessages = conv.messages.toMutableList().apply { addAll(flushed) }
                conversationStore.save(conv.copy(
                    messages = newMessages,
                    pendingMessages = mutableListOf(),
                    lastMessageAt = System.currentTimeMillis()
                ))

                connectionManager.registerConversation(conv.id, envId)
                val out = connectionManager.output(conv.id)
                out.reset()
                out.setRunning(true)

                val combinedText = pending.joinToString("\n\n") { it.text }
                connectionManager.send(
                    ClientMessage.Chat(
                        message = combinedText,
                        workingDirectory = conv.workingDirectory ?: connection.defaultWorkingDirectory?.value,
                        sessionId = conv.sessionId,
                        isNewSession = conv.sessionId == null,
                        conversationId = conv.id,
                        conversationName = conv.name,
                        effort = conv.defaultEffort,
                        model = conv.defaultModel
                    ),
                    envId
                )
            }
        flushPendingMessages()
    }

    fun forkConversation(upToMessageId: String) {
        val conv = _conversation.value
        if (conv.sessionId == null) return
        val idx = conv.messages.indexOfFirst { it.id == upToMessageId }
        if (idx < 0) return
        val forkedMessages = conv.messages.subList(0, idx + 1).map { it.copy() }.toMutableList()
        val forked = Conversation(
            name = conv.name,
            symbol = conv.symbol,
            sessionId = conv.sessionId,
            workingDirectory = conv.workingDirectory,
            environmentId = conv.environmentId,
            messages = forkedMessages,
            pendingFork = true,
            lastMessageAt = System.currentTimeMillis()
        )
        conversationStore.save(forked)
        _conversation.value = forked
    }

    fun injectTestWidgets() {
        val conv = _conversation.value
        val widgetMessage = ChatMessage(
            isUser = false,
            text = "Here are test widgets:",
            toolCalls = mutableListOf(
                ToolCall(
                    name = "mcp__widgets__pie_chart",
                    input = """{"title":"Language Usage","slices":[{"label":"Kotlin","value":45},{"label":"Swift","value":30},{"label":"TypeScript","value":15},{"label":"Go","value":10}]}"""
                ),
                ToolCall(
                    name = "mcp__widgets__timeline",
                    input = """{"title":"Release History","events":[{"date":"Mar 2026","title":"v1.0 Launch","description":"Initial iOS release","color":"blue"},{"date":"Mar 2026","title":"v1.1 Android","description":"Android app ported","color":"green"},{"date":"Apr 2026","title":"v1.2 Widgets","description":"Widget views added","color":"purple"}]}"""
                ),
                ToolCall(
                    name = "mcp__widgets__tree",
                    input = """{"root":{"label":"cloude","children":[{"label":"android","children":[{"label":"app","children":[{"label":"build.gradle.kts"},{"label":"src"}]},{"label":"gradle"}]},{"label":"Cloude","children":[{"label":"App"},{"label":"Features"},{"label":"Shared"}]},{"label":"linux-relay","children":[{"label":"index.js"},{"label":"handlers.js"}]}]}}"""
                ),
                ToolCall(
                    name = "mcp__widgets__color_palette",
                    input = """{"title":"Cloude Theme","colors":[{"hex":"#CC7257","label":"Accent"},{"hex":"#7AB87A","label":"PastelGreen"},{"hex":"#B54E5E","label":"PastelRed"},{"hex":"#64B5F6","label":"LinkBlue"},{"hex":"#FFD54F","label":"FolderYellow"}]}"""
                )
            )
        )
        val newMessages = conv.messages.toMutableList().apply { add(widgetMessage) }
        _conversation.value = conv.copy(messages = newMessages, lastMessageAt = System.currentTimeMillis())
        persistConversation()
    }

    fun searchFiles(query: String) {
        val envId = activeEnvId ?: return
        val workingDir = _conversation.value.workingDirectory
            ?: connectionManager.connection(envId)?.defaultWorkingDirectory?.value ?: return
        pendingFileSearchQuery = query
        val serverQuery = if (query.contains('/')) query.substringAfterLast('/') else query
        connectionManager.send(ClientMessage.SearchFiles(serverQuery, workingDir), envId)
    }

    fun clearFileSearchResults() {
        _fileSearchResults.value = emptyList()
    }

    fun exportConversation(): String {
        val conv = _conversation.value
        return buildString {
            appendLine("# ${conv.name}")
            appendLine()
            conv.messages.forEach { msg ->
                val role = if (msg.isUser) "**User**" else "**Assistant**"
                appendLine("$role:")
                appendLine()
                if (msg.toolCalls.isNotEmpty()) {
                    msg.toolCalls.forEach { tc ->
                        val status = if (tc.state == ToolCallState.complete) "done" else "running"
                        appendLine("> Tool: ${tc.name} ($status)")
                        tc.resultSummary?.let { appendLine("> $it") }
                    }
                    appendLine()
                }
                if (msg.text.isNotBlank()) {
                    appendLine(msg.text)
                    appendLine()
                }
                msg.costUsd?.let { appendLine("*${msg.model ?: ""}  $${"%.4f".format(it)}*") }
                appendLine("---")
                appendLine()
            }
            appendLine("*Total cost: $${"%.4f".format(conv.totalCost)}*")
        }
    }

    private fun handleDeviceToolCall(name: String, input: String?, conversationId: String?) {
        val action = name.removePrefix("mcp__ios__")
        val params = input?.let {
            try { deviceJson.parseToJsonElement(it).jsonObject } catch (_: Exception) { null }
        }
        when (action) {
            "haptic" -> _deviceActions.tryEmit(
                DeviceAction.Haptic(params?.get("style")?.jsonPrimitive?.content ?: "medium")
            )
            "notify" -> params?.get("message")?.jsonPrimitive?.content?.let {
                _deviceActions.tryEmit(DeviceAction.Notify(it))
            }
            "screenshot" -> _deviceActions.tryEmit(DeviceAction.Screenshot(conversationId))
        }
    }

    fun toggleCollapse(messageId: String) {
        val conv = _conversation.value
        val updated = conv.messages.map {
            if (it.id == messageId) it.copy(isCollapsed = !it.isCollapsed) else it
        }
        _conversation.value = conv.copy(messages = updated.toMutableList())
    }

    private fun resolveConversationId(messageConvId: String?): String? {
        if (messageConvId != null) return messageConvId
        val activeId = _conversation.value.id
        val out = connectionManager.output(activeId)
        if (out.isRunning.value || out.fullText.isNotEmpty()) return activeId
        return null
    }

    private fun handleMessage(message: ServerMessage) {
        when (message) {
            is ServerMessage.Output -> {
                val convId = resolveConversationId(message.conversationId) ?: return
                connectionManager.output(convId).appendText(message.text)
            }

            is ServerMessage.Status -> {
                val convId = resolveConversationId(message.conversationId) ?: _conversation.value.id
                val out = connectionManager.output(convId)
                Log.d("Cloude", "VM Status: ${message.state} convId=$convId")
                when (message.state) {
                    AgentState.running -> {
                        out.setRunning(true)
                        out.setCompacting(false)
                    }
                    AgentState.compacting -> {
                        out.setCompacting(true)
                        out.setRunning(true)
                    }
                    AgentState.idle -> finalizeAssistantMessage(convId)
                }
            }

            is ServerMessage.ToolCall -> {
                if (message.name.startsWith("mcp__ios__")) {
                    handleDeviceToolCall(message.name, message.input, message.conversationId)
                } else {
                    val convId = resolveConversationId(message.conversationId) ?: return
                    connectionManager.output(convId).addToolCall(
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
            }

            is ServerMessage.ToolResult -> {
                val convId = resolveConversationId(message.conversationId) ?: return
                connectionManager.output(convId).updateToolResult(message.toolId, message.summary, message.output)
            }

            is ServerMessage.SessionId -> {
                val convId = message.conversationId ?: _conversation.value.id
                connectionManager.output(convId).newSessionId = message.id
                if (convId == _conversation.value.id) {
                    _conversation.value = _conversation.value.copy(sessionId = message.id)
                    persistConversation()
                } else {
                    conversationStore.conversation(convId)?.let { conv ->
                        conversationStore.save(conv.copy(sessionId = message.id))
                    }
                }
            }

            is ServerMessage.RunStats -> {
                val convId = resolveConversationId(message.conversationId) ?: return
                connectionManager.output(convId).runStats = Triple(message.durationMs, message.costUsd, message.model)
            }

            is ServerMessage.MessageUUID -> {
                val convId = resolveConversationId(message.conversationId) ?: return
                connectionManager.output(convId).messageUUID = message.uuid
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

            is ServerMessage.Plans -> {
                _plans.value = message.stages
            }

            is ServerMessage.Memories -> {
                _memorySections.value = message.sections
            }

            is ServerMessage.PlanDeleted -> {
                val current = _plans.value?.toMutableMap() ?: return
                current[message.stage] = current[message.stage]?.filter { it.filename != message.filename } ?: emptyList()
                _plans.value = current
            }

            is ServerMessage.NameSuggestion -> {
                val convId = message.conversationId
                if (convId == _conversation.value.id) {
                    val conv = _conversation.value
                    if (!conv.userRenamed) {
                        _conversation.value = conv.copy(name = message.name, symbol = message.symbol)
                        persistConversation()
                    }
                } else {
                    conversationStore.conversation(convId)?.let { conv ->
                        if (!conv.userRenamed) {
                            conversationStore.save(conv.copy(name = message.name, symbol = message.symbol))
                        }
                    }
                }
            }

            is ServerMessage.HistorySync -> {
                val conv = _conversation.value
                if (message.sessionId == conv.sessionId) {
                    val historyMessages = message.messages.map { hm ->
                        ChatMessage(
                            isUser = hm.role == "user",
                            text = hm.text,
                            timestamp = ((hm.timestamp ?: 0.0) * 1000).toLong(),
                            toolCalls = hm.toolCalls.map { tc ->
                                ToolCall(
                                    name = tc.name,
                                    input = tc.input,
                                    toolId = tc.toolId,
                                    resultSummary = tc.summary,
                                    resultOutput = tc.output
                                )
                            }.toMutableList()
                        )
                    }
                    _conversation.value = conv.copy(
                        messages = historyMessages.toMutableList(),
                        lastMessageAt = System.currentTimeMillis()
                    )
                    persistConversation()
                }
            }

            is ServerMessage.FileSearchResults -> {
                val fullQuery = pendingFileSearchQuery
                val results = if (fullQuery != null && fullQuery.contains('/')) {
                    message.files.filter { it.lowercase().contains(fullQuery.lowercase()) }
                } else message.files
                _fileSearchResults.value = results
            }

            is ServerMessage.AuthResult -> {
                if (message.success) flushAllPendingMessages()
            }

            is ServerMessage.Error -> {
                val convId = _conversation.value.id
                connectionManager.output(convId).appendText("\n**Error:** ${message.message}")
                finalizeAssistantMessage(convId)
            }

            else -> {}
        }
    }

    private fun finalizeAssistantMessage(conversationId: String) {
        val out = connectionManager.output(conversationId)
        Log.d("Cloude", "finalizeAssistantMessage: convId=$conversationId fullText=${out.fullText.length} toolCalls=${out.toolCalls.value.size}")
        val text = out.fullText
        if (text.isEmpty() && out.toolCalls.value.isEmpty()) {
            out.setRunning(false)
            out.setCompacting(false)
            return
        }

        out.completeExecutingTools()
        val assistantMessage = ChatMessage(
            isUser = false,
            text = text,
            toolCalls = out.toolCalls.value.toMutableList(),
            durationMs = out.runStats?.first,
            costUsd = out.runStats?.second,
            serverUUID = out.messageUUID,
            model = out.runStats?.third
        )

        val isActive = conversationId == _conversation.value.id
        val conv = if (isActive) _conversation.value else conversationStore.conversation(conversationId)
        if (conv == null) {
            out.reset()
            return
        }

        val newMessages = conv.messages.toMutableList().apply { add(assistantMessage) }
        val updated = conv.copy(messages = newMessages, lastMessageAt = System.currentTimeMillis())

        if (isActive) {
            _conversation.value = updated
            persistConversation()
        } else {
            conversationStore.save(updated)
        }

        Log.d("Cloude", "finalizeAssistantMessage: done convId=$conversationId")

        val assistantCount = updated.messages.count { !it.isUser }
        if ((assistantCount == 2 || (assistantCount > 0 && assistantCount % 5 == 0)) && !updated.userRenamed) {
            val envId = if (isActive) activeEnvId else connectionManager.connectionForConversation(conversationId)?.environmentId
            if (envId != null) {
                val contextMessages = updated.messages.takeLast(10).map {
                    (if (it.isUser) "User: " else "Assistant: ") + it.text.take(300)
                }
                val lastUserMsg = updated.messages.lastOrNull { it.isUser }?.text ?: ""
                connectionManager.send(
                    ClientMessage.SuggestName(text = lastUserMsg, context = contextMessages, conversationId = updated.id),
                    envId
                )
            }
        }

        out.reset()
        flushPendingMessages()
    }

    private fun persistConversation() {
        val conv = _conversation.value
        if (!conv.isEmpty) conversationStore.save(conv)
    }
}

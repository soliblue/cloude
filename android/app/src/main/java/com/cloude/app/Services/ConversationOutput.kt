package com.cloude.app.Services

import com.cloude.app.Models.ToolCall
import com.cloude.app.Models.ToolCallState
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow

class ConversationOutput {
    private val _text = MutableStateFlow("")
    val text: StateFlow<String> = _text

    private val _toolCalls = MutableStateFlow<List<ToolCall>>(emptyList())
    val toolCalls: StateFlow<List<ToolCall>> = _toolCalls

    private val _isRunning = MutableStateFlow(false)
    val isRunning: StateFlow<Boolean> = _isRunning

    private val _isCompacting = MutableStateFlow(false)
    val isCompacting: StateFlow<Boolean> = _isCompacting

    var newSessionId: String? = null
    var messageUUID: String? = null
    var runStats: Triple<Int, Double, String?>? = null
    var fullText: String = ""

    fun appendText(chunk: String) {
        fullText += chunk
        _text.value = fullText
    }

    fun addToolCall(toolCall: ToolCall) {
        _toolCalls.value = _toolCalls.value + toolCall
    }

    fun updateToolResult(toolId: String, summary: String?, output: String?) {
        _toolCalls.value = _toolCalls.value.map {
            if (it.toolId == toolId) it.copy(state = ToolCallState.complete, resultSummary = summary, resultOutput = output)
            else it
        }
    }

    fun completeExecutingTools() {
        _toolCalls.value = _toolCalls.value.map {
            if (it.state == ToolCallState.executing) it.copy(state = ToolCallState.complete)
            else it
        }
    }

    fun setRunning(running: Boolean) {
        _isRunning.value = running
    }

    fun setCompacting(compacting: Boolean) {
        _isCompacting.value = compacting
    }

    fun reset() {
        fullText = ""
        _text.value = ""
        _toolCalls.value = emptyList()
        _isRunning.value = false
        _isCompacting.value = false
        newSessionId = null
        messageUUID = null
        runStats = null
    }
}

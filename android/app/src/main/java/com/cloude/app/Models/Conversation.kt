package com.cloude.app.Models

import kotlinx.serialization.Serializable
import java.util.UUID

@Serializable
data class Conversation(
    val id: String = UUID.randomUUID().toString(),
    var name: String = randomNames.random(),
    var symbol: String? = null,
    var sessionId: String? = null,
    var workingDirectory: String? = null,
    val createdAt: Long = System.currentTimeMillis(),
    var lastMessageAt: Long = System.currentTimeMillis(),
    var messages: MutableList<ChatMessage> = mutableListOf(),
    var pendingMessages: MutableList<ChatMessage> = mutableListOf(),
    var defaultEffort: String? = null,
    var defaultModel: String? = null,
    var environmentId: String? = null,
    var userRenamed: Boolean = false,
    var pendingFork: Boolean = false
) {
    val isEmpty: Boolean
        get() = messages.isEmpty() && pendingMessages.isEmpty() && sessionId == null

    val totalCost: Double
        get() = messages.mapNotNull { it.costUsd }.sum()

    companion object {
        val randomNames = listOf(
            "Spark", "Nova", "Pulse", "Echo", "Drift", "Blaze", "Frost", "Dusk",
            "Dawn", "Flux", "Glow", "Haze", "Mist", "Peak", "Reef", "Sage",
            "Tide", "Vale", "Wave", "Zen", "Bolt", "Cove", "Edge", "Fern",
            "Grid", "Hive", "Jade", "Kite", "Leaf", "Maze", "Nest", "Opal",
            "Pine", "Quill", "Rush", "Sand", "Twig", "Vine", "Wisp", "Yarn"
        )
    }
}

@Serializable
data class ChatMessage(
    val id: String = UUID.randomUUID().toString(),
    val isUser: Boolean,
    var text: String,
    val timestamp: Long = System.currentTimeMillis(),
    var toolCalls: MutableList<ToolCall> = mutableListOf(),
    var durationMs: Int? = null,
    var costUsd: Double? = null,
    var isQueued: Boolean = false,
    var wasInterrupted: Boolean = false,
    var serverUUID: String? = null,
    var model: String? = null,
    var isCollapsed: Boolean = false,
    var imageCount: Int = 0,
    var fileCount: Int = 0
)

@Serializable
data class ToolCall(
    val name: String,
    val input: String? = null,
    val toolId: String = UUID.randomUUID().toString(),
    val parentToolId: String? = null,
    var textPosition: Int? = null,
    var state: ToolCallState = ToolCallState.complete,
    var resultSummary: String? = null,
    var resultOutput: String? = null,
    var editInfo: EditInfo? = null
)

@Serializable
enum class ToolCallState {
    executing, complete
}

@Serializable
enum class EffortLevel(val displayName: String) {
    low("Low"), medium("Medium"), high("High"), max("Max")
}

@Serializable
enum class ModelSelection(val displayName: String) {
    opus("Opus"), sonnet("Sonnet"), haiku("Haiku")
}

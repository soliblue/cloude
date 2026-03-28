package com.cloude.app.Models

import kotlinx.serialization.Serializable

@Serializable
enum class AgentState {
    idle, running, compacting
}

@Serializable
data class EditInfo(
    val oldString: String? = null,
    val newString: String? = null,
    val filePath: String? = null
)

@Serializable
data class StoredToolCall(
    val name: String,
    val input: String? = null,
    val toolId: String,
    val summary: String? = null,
    val output: String? = null
)

@Serializable
data class FileEntry(
    val name: String,
    val path: String,
    val isDirectory: Boolean = false,
    val size: Long? = null,
    val modified: Double? = null,
    val mimeType: String? = null
)

@Serializable
data class GitStatusInfo(
    val branch: String = "",
    val ahead: Int = 0,
    val behind: Int = 0,
    val files: List<GitFileStatus> = emptyList()
)

@Serializable
data class GitFileStatus(
    val path: String,
    val staged: String? = null,
    val unstaged: String? = null
)

@Serializable
data class MemorySection(
    val title: String,
    val content: String
)

@Serializable
data class AgentProcessInfo(
    val pid: Int,
    val command: String,
    val startTime: Double? = null,
    val conversationId: String? = null,
    val conversationName: String? = null
)

@Serializable
data class Skill(
    val name: String,
    val description: String? = null,
    val icon: String? = null,
    val aliases: List<String> = emptyList(),
    val userInvocable: Boolean = false,
    val parameters: List<SkillParameter> = emptyList()
)

@Serializable
data class SkillParameter(
    val name: String,
    val description: String? = null,
    val required: Boolean = false
)

@Serializable
data class HistoryMessage(
    val role: String,
    val text: String,
    val timestamp: Double? = null,
    val toolCalls: List<StoredToolCall> = emptyList()
)

@Serializable
data class RemoteSession(
    val id: String,
    val workingDirectory: String? = null,
    val startedAt: Double? = null
)

@Serializable
data class PlanItem(
    val filename: String,
    val title: String,
    val icon: String? = null,
    val description: String? = null,
    val priority: Int = 10,
    val tags: List<String> = emptyList(),
    val content: String? = null,
    val path: String? = null
)

@Serializable
data class UsageStats(
    val totalSessions: Int = 0,
    val totalMessages: Int = 0,
    val dailyActivity: Map<String, Int> = emptyMap(),
    val modelUsage: Map<String, ModelTokenUsage> = emptyMap(),
    val hourCounts: Map<String, Int> = emptyMap(),
    val longestSession: Int? = null
)

@Serializable
data class ModelTokenUsage(
    val inputTokens: Long = 0,
    val outputTokens: Long = 0
)

@Serializable
data class AttachedFilePayload(
    val name: String,
    val data: String
)

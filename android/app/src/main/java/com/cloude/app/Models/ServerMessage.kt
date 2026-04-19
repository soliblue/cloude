package com.cloude.app.Models

import android.util.Log
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.boolean
import kotlinx.serialization.json.booleanOrNull
import kotlinx.serialization.json.double
import kotlinx.serialization.json.doubleOrNull
import kotlinx.serialization.json.int
import kotlinx.serialization.json.intOrNull
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.long

sealed class ServerMessage {
    data class Output(val text: String, val conversationId: String? = null) : ServerMessage()
    data class Status(val state: AgentState, val conversationId: String? = null) : ServerMessage()
    data object AuthRequired : ServerMessage()
    data class AuthResult(val success: Boolean, val message: String? = null) : ServerMessage()
    data class Error(val message: String) : ServerMessage()
    data class DirectoryListing(val path: String, val entries: List<FileEntry>) : ServerMessage()
    data class FileContent(val path: String, val data: String, val mimeType: String, val size: Long, val truncated: Boolean = false) : ServerMessage()
    data class SessionId(val id: String, val conversationId: String? = null) : ServerMessage()
    data class MissedResponse(val sessionId: String, val text: String, val completedAt: Double, val toolCalls: List<StoredToolCall> = emptyList()) : ServerMessage()
    data class NoMissedResponse(val sessionId: String) : ServerMessage()
    data class ToolCall(val name: String, val input: String? = null, val toolId: String, val parentToolId: String? = null, val conversationId: String? = null, val textPosition: Int? = null, val editInfo: EditInfo? = null) : ServerMessage()
    data class ToolResult(val toolId: String, val summary: String? = null, val output: String? = null, val conversationId: String? = null) : ServerMessage()
    data class RunStats(val durationMs: Int, val costUsd: Double, val model: String? = null, val conversationId: String? = null) : ServerMessage()
    data class GitStatusResult(val status: GitStatusInfo) : ServerMessage()
    data class GitDiffResult(val path: String, val diff: String) : ServerMessage()
    data class GitCommitResult(val success: Boolean, val message: String? = null) : ServerMessage()
    data class GitLogResult(val path: String, val commits: List<GitCommit>) : ServerMessage()
    data class Transcription(val text: String) : ServerMessage()
    data class WhisperReady(val ready: Boolean) : ServerMessage()
    data class DefaultWorkingDirectory(val path: String) : ServerMessage()
    data class Skills(val skills: List<Skill>) : ServerMessage()
    data class HistorySync(val sessionId: String, val messages: List<HistoryMessage>) : ServerMessage()
    data class HistorySyncError(val sessionId: String, val error: String) : ServerMessage()
    data class FileChunk(val path: String, val chunkIndex: Int, val totalChunks: Int, val data: String, val mimeType: String, val size: Long) : ServerMessage()
    data class FileThumbnail(val path: String, val data: String, val fullSize: Long) : ServerMessage()
    data class FileSearchResults(val files: List<String>) : ServerMessage()
    data class MessageUUID(val uuid: String, val conversationId: String? = null) : ServerMessage()
    data class NameSuggestion(val name: String, val symbol: String? = null, val conversationId: String) : ServerMessage()

    companion object {
        private val json = Json { ignoreUnknownKeys = true; isLenient = true }

        fun decode(text: String): ServerMessage? = try {
            doDecode(text)
        } catch (e: Exception) {
            Log.e("Cloude", "ServerMessage decode error: ${e.message} for: ${text.take(200)}")
            null
        }

        private fun doDecode(text: String): ServerMessage? {
            val obj = json.parseToJsonElement(text).jsonObject
            val type = obj["type"]?.jsonPrimitive?.content ?: return null

            return when (type) {
                "output" -> Output(
                    text = obj.str("text") ?: "",
                    conversationId = obj.strOrNull("conversationId")
                )
                "status" -> Status(
                    state = when (obj.str("state")) {
                        "running" -> AgentState.running
                        "compacting" -> AgentState.compacting
                        else -> AgentState.idle
                    },
                    conversationId = obj.strOrNull("conversationId")
                )
                "auth_required" -> AuthRequired
                "auth_result" -> AuthResult(
                    success = obj["success"]?.jsonPrimitive?.boolean ?: false,
                    message = obj.strOrNull("message")
                )
                "error" -> Error(message = obj.str("message") ?: "Unknown error")
                "session_id" -> SessionId(
                    id = obj.str("id") ?: "",
                    conversationId = obj.strOrNull("conversationId")
                )
                "tool_call" -> ToolCall(
                    name = obj.str("name") ?: "",
                    input = obj.strOrNull("input"),
                    toolId = obj.str("toolId") ?: "",
                    parentToolId = obj.strOrNull("parentToolId"),
                    conversationId = obj.strOrNull("conversationId"),
                    textPosition = obj["textPosition"]?.jsonPrimitive?.intOrNull,
                    editInfo = obj["editInfo"]?.let { json.decodeFromJsonElement(EditInfo.serializer(), it) }
                )
                "tool_result" -> ToolResult(
                    toolId = obj.str("toolId") ?: "",
                    summary = obj.strOrNull("summary"),
                    output = obj.strOrNull("output"),
                    conversationId = obj.strOrNull("conversationId")
                )
                "run_stats" -> RunStats(
                    durationMs = obj["durationMs"]?.jsonPrimitive?.int ?: 0,
                    costUsd = obj["costUsd"]?.jsonPrimitive?.double ?: 0.0,
                    model = obj.strOrNull("model"),
                    conversationId = obj.strOrNull("conversationId")
                )
                "message_uuid" -> MessageUUID(
                    uuid = obj.str("uuid") ?: "",
                    conversationId = obj.strOrNull("conversationId")
                )
                "missed_response" -> MissedResponse(
                    sessionId = obj.str("sessionId") ?: "",
                    text = obj.str("text") ?: "",
                    completedAt = obj["completedAt"]?.jsonPrimitive?.doubleOrNull ?: 0.0,
                    toolCalls = obj["toolCalls"]?.jsonArray?.map { json.decodeFromJsonElement(StoredToolCall.serializer(), it) } ?: emptyList()
                )
                "no_missed_response" -> NoMissedResponse(sessionId = obj.str("sessionId") ?: "")
                "directory_listing" -> DirectoryListing(
                    path = obj.str("path") ?: "",
                    entries = obj["entries"]?.jsonArray?.map { json.decodeFromJsonElement(FileEntry.serializer(), it) } ?: emptyList()
                )
                "file_content" -> FileContent(
                    path = obj.str("path") ?: "",
                    data = obj.str("data") ?: "",
                    mimeType = obj.str("mimeType") ?: "",
                    size = obj["size"]?.jsonPrimitive?.long ?: 0,
                    truncated = obj["truncated"]?.jsonPrimitive?.booleanOrNull ?: false
                )
                "git_status_result" -> GitStatusResult(
                    status = json.decodeFromJsonElement(GitStatusInfo.serializer(), obj["status"]?.jsonObject ?: return null)
                )
                "git_diff_result" -> GitDiffResult(
                    path = obj.str("path") ?: "",
                    diff = obj.str("diff") ?: ""
                )
                "git_commit_result" -> GitCommitResult(
                    success = obj["success"]?.jsonPrimitive?.boolean ?: false,
                    message = obj.strOrNull("message")
                )
                "git_log_result" -> GitLogResult(
                    path = obj.str("path") ?: "",
                    commits = obj["commits"]?.jsonArray?.map { json.decodeFromJsonElement(GitCommit.serializer(), it) } ?: emptyList()
                )
                "transcription" -> Transcription(text = obj.str("text") ?: "")
                "whisper_ready" -> WhisperReady(ready = obj["ready"]?.jsonPrimitive?.boolean ?: false)
                "default_working_directory" -> DefaultWorkingDirectory(path = obj.str("path") ?: "")
                "skills" -> Skills(
                    skills = obj["skills"]?.jsonArray?.map { json.decodeFromJsonElement(Skill.serializer(), it) } ?: emptyList()
                )
                "history_sync" -> HistorySync(
                    sessionId = obj.str("sessionId") ?: "",
                    messages = obj["messages"]?.jsonArray?.map { json.decodeFromJsonElement(HistoryMessage.serializer(), it) } ?: emptyList()
                )
                "history_sync_error" -> HistorySyncError(
                    sessionId = obj.str("sessionId") ?: "",
                    error = obj.str("error") ?: ""
                )
                "file_chunk" -> FileChunk(
                    path = obj.str("path") ?: "",
                    chunkIndex = obj["chunkIndex"]?.jsonPrimitive?.int ?: 0,
                    totalChunks = obj["totalChunks"]?.jsonPrimitive?.int ?: 0,
                    data = obj.str("data") ?: "",
                    mimeType = obj.str("mimeType") ?: "",
                    size = obj["size"]?.jsonPrimitive?.long ?: 0
                )
                "file_thumbnail" -> FileThumbnail(
                    path = obj.str("path") ?: "",
                    data = obj.str("data") ?: "",
                    fullSize = obj["fullSize"]?.jsonPrimitive?.long ?: 0
                )
                "file_search_results" -> FileSearchResults(
                    files = obj["files"]?.jsonArray?.map { it.jsonPrimitive.content } ?: emptyList()
                )
                "name_suggestion" -> NameSuggestion(
                    name = obj.str("name") ?: "",
                    symbol = obj.strOrNull("symbol"),
                    conversationId = obj.str("conversationId") ?: ""
                )
                "team_created", "teammate_spawned", "teammate_update", "team_deleted" -> null
                else -> null
            }
        }

        private fun JsonObject.str(key: String): String? =
            this[key]?.jsonPrimitive?.content

        private fun JsonObject.strOrNull(key: String): String? =
            this[key]?.jsonPrimitive?.takeIf { it.isString }?.content
    }
}

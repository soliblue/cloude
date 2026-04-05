package com.cloude.app.Models

import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonArray
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put

sealed class ClientMessage {
    data class Chat(
        val message: String,
        val workingDirectory: String? = null,
        val sessionId: String? = null,
        val isNewSession: Boolean = true,
        val imagesBase64: List<String>? = null,
        val filesBase64: List<AttachedFilePayload>? = null,
        val conversationId: String? = null,
        val conversationName: String? = null,
        val forkSession: Boolean = false,
        val effort: String? = null,
        val model: String? = null
    ) : ClientMessage()

    data class Abort(val conversationId: String? = null) : ClientMessage()
    data class Auth(val token: String) : ClientMessage()
    data class ListDirectory(val path: String) : ClientMessage()
    data class GetFile(val path: String) : ClientMessage()
    data class GetFileFullQuality(val path: String) : ClientMessage()
    data class RequestMissedResponse(val sessionId: String) : ClientMessage()
    data class GitStatus(val path: String) : ClientMessage()
    data class GitDiff(val path: String, val file: String? = null, val staged: Boolean = false) : ClientMessage()
    data class GitCommit(val path: String, val message: String, val files: List<String>) : ClientMessage()
    data class GitLog(val path: String, val count: Int = 10) : ClientMessage()
    data class Transcribe(val audioBase64: String) : ClientMessage()
    data class GetMemories(val workingDirectory: String) : ClientMessage()
    data object GetProcesses : ClientMessage()
    data class KillProcess(val pid: Int) : ClientMessage()
    data object KillAllProcesses : ClientMessage()
    data class SyncHistory(val sessionId: String, val workingDirectory: String) : ClientMessage()
    data class SearchFiles(val query: String, val workingDirectory: String) : ClientMessage()
    data class ListRemoteSessions(val workingDirectory: String) : ClientMessage()
    data class SuggestName(val text: String, val context: List<String> = emptyList(), val conversationId: String) : ClientMessage()
    data class GetPlans(val workingDirectory: String) : ClientMessage()
    data class DeletePlan(val stage: String, val filename: String, val workingDirectory: String) : ClientMessage()
    data object GetUsageStats : ClientMessage()
    data class TerminalExec(val command: String, val workingDirectory: String, val terminalId: String? = null) : ClientMessage()
    data class TerminalInput(val text: String, val terminalId: String? = null) : ClientMessage()

    fun toJson(): String = buildJsonObject {
        when (val msg = this@ClientMessage) {
            is Chat -> {
                put("type", "chat")
                put("message", msg.message)
                msg.workingDirectory?.let { put("workingDirectory", it) }
                msg.sessionId?.let { put("sessionId", it) }
                put("isNewSession", msg.isNewSession)
                msg.imagesBase64?.let { images ->
                    put("imagesBase64", buildJsonArray { images.forEach { add(JsonPrimitive(it)) } })
                }
                msg.filesBase64?.let { files ->
                    put("filesBase64", buildJsonArray {
                        files.forEach { f ->
                            add(buildJsonObject {
                                put("name", f.name)
                                put("data", f.data)
                            })
                        }
                    })
                }
                msg.conversationId?.let { put("conversationId", it) }
                msg.conversationName?.let { put("conversationName", it) }
                put("forkSession", msg.forkSession)
                msg.effort?.let { put("effort", it) }
                msg.model?.let { put("model", it) }
            }
            is Abort -> {
                put("type", "abort")
                msg.conversationId?.let { put("conversationId", it) }
            }
            is Auth -> {
                put("type", "auth")
                put("token", msg.token)
            }
            is ListDirectory -> {
                put("type", "list_directory")
                put("path", msg.path)
            }
            is GetFile -> {
                put("type", "get_file")
                put("path", msg.path)
            }
            is GetFileFullQuality -> {
                put("type", "get_file_full_quality")
                put("path", msg.path)
            }
            is RequestMissedResponse -> {
                put("type", "request_missed_response")
                put("sessionId", msg.sessionId)
            }
            is GitStatus -> {
                put("type", "git_status")
                put("path", msg.path)
            }
            is GitDiff -> {
                put("type", "git_diff")
                put("path", msg.path)
                msg.file?.let { put("file", it) }
                if (msg.staged) put("staged", true)
            }
            is GitCommit -> {
                put("type", "git_commit")
                put("path", msg.path)
                put("message", msg.message)
                put("files", buildJsonArray { msg.files.forEach { add(JsonPrimitive(it)) } })
            }
            is GitLog -> {
                put("type", "git_log")
                put("path", msg.path)
                put("count", msg.count)
            }
            is Transcribe -> {
                put("type", "transcribe")
                put("audioBase64", msg.audioBase64)
            }
            is GetMemories -> {
                put("type", "get_memories")
                put("workingDirectory", msg.workingDirectory)
            }
            is GetProcesses -> put("type", "get_processes")
            is KillProcess -> {
                put("type", "kill_process")
                put("pid", msg.pid)
            }
            is KillAllProcesses -> put("type", "kill_all_processes")
            is SyncHistory -> {
                put("type", "sync_history")
                put("sessionId", msg.sessionId)
                put("workingDirectory", msg.workingDirectory)
            }
            is SearchFiles -> {
                put("type", "search_files")
                put("query", msg.query)
                put("workingDirectory", msg.workingDirectory)
            }
            is ListRemoteSessions -> {
                put("type", "list_remote_sessions")
                put("workingDirectory", msg.workingDirectory)
            }
            is SuggestName -> {
                put("type", "suggest_name")
                put("text", msg.text)
                put("context", buildJsonArray { msg.context.forEach { add(JsonPrimitive(it)) } })
                put("conversationId", msg.conversationId)
            }
            is GetPlans -> {
                put("type", "get_plans")
                put("workingDirectory", msg.workingDirectory)
            }
            is DeletePlan -> {
                put("type", "delete_plan")
                put("stage", msg.stage)
                put("filename", msg.filename)
                put("workingDirectory", msg.workingDirectory)
            }
            is GetUsageStats -> put("type", "get_usage_stats")
            is TerminalExec -> {
                put("type", "terminal_exec")
                put("command", msg.command)
                put("workingDirectory", msg.workingDirectory)
                msg.terminalId?.let { put("terminalId", it) }
            }
            is TerminalInput -> {
                put("type", "terminal_input")
                put("text", msg.text)
                msg.terminalId?.let { put("terminalId", it) }
            }
        }
    }.toString()
}

package com.cloude.app.Models

import android.content.Context
import android.util.Log
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import java.io.File

class ConversationStore(private val context: Context) {
    private val json = Json { ignoreUnknownKeys = true; prettyPrint = false }
    private val conversationsDir: File
        get() = File(context.filesDir, "conversations").also { it.mkdirs() }

    val imagesDir: File
        get() = File(context.filesDir, "image_previews").also { it.mkdirs() }

    private val _conversations = MutableStateFlow<List<Conversation>>(emptyList())
    val conversations: StateFlow<List<Conversation>> = _conversations

    init {
        load()
    }

    private fun load() {
        val dir = conversationsDir
        if (!dir.exists()) return
        val loaded = dir.listFiles { f -> f.extension == "json" }
            ?.mapNotNull { file ->
                try {
                    json.decodeFromString<Conversation>(file.readText())
                } catch (e: Exception) {
                    Log.w("Cloude", "Failed to load conversation ${file.name}: ${e.message}")
                    null
                }
            }
            ?.sortedByDescending { it.lastMessageAt }
            ?: emptyList()
        _conversations.value = loaded
        Log.d("Cloude", "Loaded ${loaded.size} conversations from disk")
    }

    fun save(conversation: Conversation) {
        val file = File(conversationsDir, "${conversation.id}.json")
        try {
            file.writeText(json.encodeToString(conversation))
        } catch (e: Exception) {
            Log.w("Cloude", "Failed to save conversation ${conversation.id}: ${e.message}")
        }
        val list = _conversations.value.toMutableList()
        val idx = list.indexOfFirst { it.id == conversation.id }
        if (idx >= 0) list[idx] = conversation else list.add(0, conversation)
        _conversations.value = list.sortedByDescending { it.lastMessageAt }
    }

    fun delete(conversationId: String) {
        File(conversationsDir, "$conversationId.json").delete()
        _conversations.value = _conversations.value.filter { it.id != conversationId }
    }

    fun conversation(id: String): Conversation? =
        _conversations.value.firstOrNull { it.id == id }
}

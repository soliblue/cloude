package com.cloude.app.Models

import java.util.UUID

enum class WindowType { Chat, Files, GitChanges }

data class ChatWindow(
    val id: String = UUID.randomUUID().toString(),
    val type: WindowType = WindowType.Chat,
    val conversationId: String? = null
)

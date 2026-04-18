package com.cloude.app.App

import android.net.Uri
import android.util.Log
import com.cloude.app.Models.WindowType
import com.cloude.app.Services.ChatViewModel
import com.cloude.app.Services.ConnectionManager
import com.cloude.app.Services.WindowManager
import com.cloude.app.Models.EnvironmentStore

class DeepLinkRouter(
    private val chatViewModel: ChatViewModel,
    private val windowManager: WindowManager,
    private val connectionManager: ConnectionManager,
    private val environmentStore: EnvironmentStore,
    private val uiActions: UIActions
) {
    interface UIActions {
        fun showSettings()
        fun showConversations()
        fun dismissAll()
    }

    private fun setActiveWindowType(type: WindowType) {
        windowManager.activeWindow?.let { windowManager.setWindowType(it.id, type) }
    }

    fun handle(uri: Uri) {
        if (uri.scheme != "cloude") return
        Log.d("Cloude", "DeepLink: $uri")

        when (uri.host) {
            "file" -> {
                uiActions.dismissAll()
                setActiveWindowType(WindowType.Files)
            }

            "files" -> {
                uiActions.dismissAll()
                setActiveWindowType(WindowType.Files)
            }

            "git" -> {
                uiActions.dismissAll()
                setActiveWindowType(WindowType.GitChanges)
            }

            "send" -> {
                uiActions.dismissAll()
                uri.getQueryParameter("text")?.let { chatViewModel.sendMessage(it) }
            }

            "search" -> {
                uiActions.dismissAll()
                uiActions.showConversations()
            }

            "conversation" -> {
                uiActions.dismissAll()
                when (uri.path) {
                    "/new" -> chatViewModel.newConversation()
                    "/model" -> chatViewModel.setModel(uri.getQueryParameter("value"))
                    "/effort" -> chatViewModel.setEffort(uri.getQueryParameter("value"))
                    else -> {
                        val id = uri.getQueryParameter("id")
                        if (id != null) chatViewModel.loadConversation(id)
                        else uiActions.showConversations()
                    }
                }
            }

            "window" -> {
                uiActions.dismissAll()
                when (uri.path) {
                    "/new" -> {
                        val type = uri.getQueryParameter("type")?.let { name ->
                            WindowType.entries.firstOrNull { it.name.equals(name, ignoreCase = true) }
                        } ?: WindowType.Chat
                        windowManager.addWindow(type)
                    }
                    "/close" -> windowManager.activeWindow?.let { windowManager.removeWindow(it.id) }
                    else -> {
                        uri.getQueryParameter("index")?.toIntOrNull()?.let { windowManager.setActive(it) }
                    }
                }
            }

            "tab" -> {
                uiActions.dismissAll()
                uri.getQueryParameter("type")?.let { name ->
                    WindowType.entries.firstOrNull { it.name.equals(name, ignoreCase = true) }
                }?.let { setActiveWindowType(it) }
            }

            "run" -> {
                if (uri.path == "/stop") chatViewModel.abort()
            }

            "environment" -> {
                val id = uri.getQueryParameter("id") ?: return
                when (uri.path) {
                    "/select" -> {
                        environmentStore.setActive(id)
                        chatViewModel.setEnvironmentId(id)
                    }
                    "/connect" -> environmentStore.environments.value
                        .firstOrNull { it.id == id }
                        ?.let { connectionManager.connectEnvironment(it) }
                    "/disconnect" -> connectionManager.disconnectEnvironment(id)
                }
            }

            "settings" -> {
                uiActions.dismissAll()
                uiActions.showSettings()
            }
        }
    }
}

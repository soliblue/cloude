package com.cloude.app.App

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.List
import androidx.compose.material.icons.filled.Folder
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material3.CenterAlignedTopAppBar
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import com.cloude.app.Models.ConversationStore
import com.cloude.app.Models.EnvironmentStore
import com.cloude.app.Services.ChatViewModel
import com.cloude.app.Services.ConnectionManager
import com.cloude.app.UI.chat.ChatScreen
import com.cloude.app.UI.chat.ConversationListSheet
import com.cloude.app.UI.files.FileBrowserScreen
import com.cloude.app.UI.settings.SettingsScreen
import com.cloude.app.UI.theme.CloudeTheme
import com.cloude.app.Utilities.Accent
import com.cloude.app.Utilities.AppTheme
import com.cloude.app.Utilities.DS
import com.cloude.app.Utilities.PastelGreen
import com.cloude.app.Utilities.PastelRed

class MainActivity : ComponentActivity() {
    private lateinit var environmentStore: EnvironmentStore
    private lateinit var conversationStore: ConversationStore
    private val connectionManager = ConnectionManager()
    private lateinit var chatViewModel: ChatViewModel

    @OptIn(ExperimentalMaterial3Api::class)
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()

        environmentStore = EnvironmentStore(applicationContext)
        conversationStore = ConversationStore(applicationContext)
        chatViewModel = ChatViewModel(connectionManager, environmentStore, conversationStore)
        chatViewModel.init()

        environmentStore.environments.value.forEach { env ->
            connectionManager.connectEnvironment(env)
        }

        environmentStore.activeEnvironmentId.value?.let { chatViewModel.setEnvironmentId(it) }

        conversationStore.conversations.value.firstOrNull()?.let {
            chatViewModel.loadConversation(it.id)
        }

        setContent {
            val appTheme by remember { mutableStateOf(AppTheme.Majorelle) }
            var showSettings by remember { mutableStateOf(false) }
            var showFiles by remember { mutableStateOf(false) }
            var showConversations by remember { mutableStateOf(false) }
            val isAuthenticated by connectionManager.isAuthenticated.collectAsState()
            val conversation by chatViewModel.conversation.collectAsState()

            CloudeTheme(appTheme = appTheme) {
                Scaffold(
                    modifier = Modifier.fillMaxSize(),
                    topBar = {
                        CenterAlignedTopAppBar(
                            title = {
                                Text(
                                    text = when {
                                        showSettings -> "Settings"
                                        showFiles -> "Files"
                                        else -> conversation.name
                                    },
                                    style = MaterialTheme.typography.titleMedium,
                                    color = MaterialTheme.colorScheme.onSurface
                                )
                            },
                            navigationIcon = {
                                if (showSettings || showFiles) {
                                    IconButton(onClick = { showSettings = false; showFiles = false }) {
                                        Icon(
                                            imageVector = Icons.AutoMirrored.Filled.ArrowBack,
                                            contentDescription = "Back",
                                            tint = MaterialTheme.colorScheme.onSurface
                                        )
                                    }
                                } else {
                                    IconButton(onClick = { showSettings = true }) {
                                        Box(contentAlignment = Alignment.BottomEnd) {
                                            Icon(
                                                imageVector = Icons.Default.Settings,
                                                contentDescription = "Settings",
                                                tint = Accent
                                            )
                                            Box(
                                                modifier = Modifier
                                                    .size(DS.Spacing.s)
                                                    .clip(CircleShape)
                                                    .background(if (isAuthenticated) PastelGreen else PastelRed)
                                                    .align(Alignment.BottomEnd)
                                            )
                                        }
                                    }
                                }
                            },
                            actions = {
                                if (!showSettings && !showFiles) {
                                    IconButton(onClick = { showFiles = true }) {
                                        Icon(
                                            imageVector = Icons.Default.Folder,
                                            contentDescription = "Files",
                                            tint = Accent
                                        )
                                    }
                                    IconButton(onClick = { showConversations = true }) {
                                        Icon(
                                            imageVector = Icons.AutoMirrored.Filled.List,
                                            contentDescription = "Conversations",
                                            tint = Accent
                                        )
                                    }
                                }
                            },
                            colors = TopAppBarDefaults.centerAlignedTopAppBarColors(
                                containerColor = MaterialTheme.colorScheme.surfaceVariant
                            )
                        )
                    },
                    containerColor = MaterialTheme.colorScheme.background
                ) { innerPadding ->
                    when {
                        showSettings -> SettingsScreen(
                            environmentStore = environmentStore,
                            connectionManager = connectionManager,
                            modifier = Modifier.padding(innerPadding)
                        )
                        showFiles -> {
                            val defaultDir = connectionManager.connection(
                                environmentStore.activeEnvironmentId.value ?: ""
                            )?.defaultWorkingDirectory?.collectAsState()?.value ?: "/"
                            val envId = environmentStore.activeEnvironmentId.value ?: ""
                            FileBrowserScreen(
                                connectionManager = connectionManager,
                                environmentId = envId,
                                initialPath = defaultDir,
                                modifier = Modifier.padding(innerPadding)
                            )
                        }
                        else -> ChatScreen(
                            viewModel = chatViewModel,
                            modifier = Modifier.padding(innerPadding)
                        )
                    }

                    if (showConversations) {
                        ConversationListSheet(
                            conversationStore = conversationStore,
                            activeConversationId = conversation.id,
                            onSelect = { chatViewModel.loadConversation(it.id) },
                            onNew = { chatViewModel.newConversation() },
                            onDelete = { conversationStore.delete(it.id) },
                            onDismiss = { showConversations = false }
                        )
                    }
                }
            }
        }
    }
}

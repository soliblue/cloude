package com.cloude.app.App

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.os.Build
import android.os.Bundle
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.util.Base64
import android.view.PixelCopy
import androidx.lifecycle.lifecycleScope
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.compose.foundation.background
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.togetherWith
import androidx.compose.animation.core.tween
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.List
import androidx.compose.material.icons.filled.AutoAwesome
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
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.cloude.app.Models.ConversationStore
import com.cloude.app.Models.EnvironmentStore
import com.cloude.app.Services.ChatViewModel
import com.cloude.app.Services.CloudeNotificationManager
import com.cloude.app.Services.ConnectionManager
import com.cloude.app.Services.DeviceAction
import kotlinx.coroutines.launch
import com.cloude.app.Services.WebSocketForegroundService
import com.cloude.app.Services.WindowManager
import com.cloude.app.UI.chat.ConversationListSheet
import com.cloude.app.UI.chat.IconPickerSheet
import com.cloude.app.UI.debug.DebugOverlay
import com.cloude.app.UI.chat.MainScreen
import com.cloude.app.UI.chat.RenameDialog
import com.cloude.app.UI.chat.SkillsSheet
import com.cloude.app.UI.settings.SettingsScreen
import com.cloude.app.UI.whiteboard.WhiteboardSheet
import com.cloude.app.UI.theme.CloudeTheme
import com.cloude.app.Utilities.Accent
import com.cloude.app.Utilities.AppTheme
import com.cloude.app.Utilities.DS
import com.cloude.app.Utilities.PastelGreen
import com.cloude.app.Utilities.PastelRed
import com.cloude.app.Utilities.symbolToIcon

class MainActivity : ComponentActivity() {
    private lateinit var environmentStore: EnvironmentStore
    private lateinit var conversationStore: ConversationStore
    private lateinit var connectionManager: ConnectionManager
    private lateinit var chatViewModel: ChatViewModel
    private lateinit var windowManager: WindowManager
    private lateinit var deepLinkRouter: DeepLinkRouter

    @OptIn(ExperimentalMaterial3Api::class)
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()

        connectionManager = ConnectionManager(applicationContext)
        environmentStore = EnvironmentStore(applicationContext)
        conversationStore = ConversationStore(applicationContext)
        chatViewModel = ChatViewModel(connectionManager, environmentStore, conversationStore)
        chatViewModel.init()
        windowManager = WindowManager(applicationContext)

        CloudeNotificationManager.createChannels(applicationContext)

        lifecycleScope.launch {
            chatViewModel.deviceActions.collect { action ->
                when (action) {
                    is DeviceAction.Haptic -> triggerHaptic(action.style)
                    is DeviceAction.Notify -> CloudeNotificationManager.notifyAgentComplete(applicationContext, action.message)
                    is DeviceAction.Screenshot -> captureScreenshot(action.conversationId)
                }
            }
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
        ) {
            ActivityCompat.requestPermissions(this, arrayOf(Manifest.permission.POST_NOTIFICATIONS), 0)
        }

        environmentStore.environments.value.forEach { env ->
            connectionManager.connectEnvironment(env)
        }

        startForegroundService(Intent(this, WebSocketForegroundService::class.java))

        environmentStore.activeEnvironmentId.value?.let { chatViewModel.setEnvironmentId(it) }

        conversationStore.conversations.value.firstOrNull()?.let {
            chatViewModel.loadConversation(it.id)
        }

        val showSettingsState = mutableStateOf(false)
        val showConversationsState = mutableStateOf(false)

        deepLinkRouter = DeepLinkRouter(
            chatViewModel = chatViewModel,
            windowManager = windowManager,
            connectionManager = connectionManager,
            environmentStore = environmentStore,
            uiActions = object : DeepLinkRouter.UIActions {
                override fun showSettings() { showSettingsState.value = true }
                override fun showConversations() { showConversationsState.value = true }
                override fun dismissAll() {
                    showSettingsState.value = false
                    showConversationsState.value = false
                }
            }
        )

        intent?.data?.let { deepLinkRouter.handle(it) }

        val prefs = getSharedPreferences("cloude", MODE_PRIVATE)
        setContent {
            var appTheme by remember {
                mutableStateOf(
                    prefs.getString("theme", null)?.let { name ->
                        AppTheme.entries.firstOrNull { it.name == name }
                    } ?: AppTheme.Majorelle
                )
            }
            var showSettings by showSettingsState
            var showConversations by showConversationsState
            var showRename by remember { mutableStateOf(false) }
            var showIconPicker by remember { mutableStateOf(false) }
            var debugOverlayEnabled by remember {
                mutableStateOf(prefs.getBoolean("debugOverlay", false))
            }
            val isAuthenticated by connectionManager.isAuthenticated.collectAsState()
            val conversation by chatViewModel.conversation.collectAsState()

            CloudeTheme(appTheme = appTheme) {
                Scaffold(
                    modifier = Modifier.fillMaxSize(),
                    topBar = {
                        CenterAlignedTopAppBar(
                            title = {
                                if (showSettings) {
                                    Text(
                                        text = "Settings",
                                        style = MaterialTheme.typography.titleMedium,
                                        color = MaterialTheme.colorScheme.onSurface
                                    )
                                } else {
                                    Row(
                                        verticalAlignment = Alignment.CenterVertically,
                                        horizontalArrangement = Arrangement.spacedBy(DS.Spacing.xs)
                                    ) {
                                        val convIcon = symbolToIcon(conversation.symbol)
                                        Box(
                                            modifier = Modifier
                                                .size(20.dp)
                                                .clip(CircleShape)
                                                .background(if (convIcon != null) Accent.copy(alpha = 0.2f) else MaterialTheme.colorScheme.onSurface.copy(alpha = 0.1f))
                                                .clickable { showIconPicker = true },
                                            contentAlignment = Alignment.Center
                                        ) {
                                            if (convIcon != null) {
                                                Icon(
                                                    imageVector = convIcon,
                                                    contentDescription = "Change icon",
                                                    tint = Accent,
                                                    modifier = Modifier.size(12.dp)
                                                )
                                            } else {
                                                Text(
                                                    text = conversation.name.take(1),
                                                    style = MaterialTheme.typography.labelSmall.copy(fontSize = 9.sp),
                                                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = DS.Opacity.l)
                                                )
                                            }
                                        }
                                        Column(
                                            horizontalAlignment = androidx.compose.ui.Alignment.CenterHorizontally,
                                            modifier = Modifier.clickable { showRename = true }
                                        ) {
                                            AnimatedContent(
                                                targetState = conversation.name,
                                                transitionSpec = { fadeIn(tween(300)) togetherWith fadeOut(tween(300)) },
                                                label = "title"
                                            ) { name ->
                                                Text(
                                                    text = name,
                                                    style = MaterialTheme.typography.titleMedium,
                                                    color = MaterialTheme.colorScheme.onSurface,
                                                    maxLines = 1,
                                                    overflow = androidx.compose.ui.text.style.TextOverflow.Ellipsis
                                                )
                                            }
                                            val workDir = conversation.workingDirectory
                                                ?: connectionManager.connection(environmentStore.activeEnvironmentId.value ?: "")?.defaultWorkingDirectory?.value
                                            if (workDir != null) {
                                                Row(
                                                    horizontalArrangement = Arrangement.spacedBy(DS.Spacing.xs),
                                                    verticalAlignment = androidx.compose.ui.Alignment.CenterVertically
                                                ) {
                                                    Text(
                                                        text = workDir.substringAfterLast('/'),
                                                        style = MaterialTheme.typography.labelSmall,
                                                        color = MaterialTheme.colorScheme.onSurface.copy(alpha = DS.Opacity.m)
                                                    )
                                                    if (conversation.totalCost > 0) {
                                                        Text(
                                                            text = "$${String.format("%.2f", conversation.totalCost)}",
                                                            style = MaterialTheme.typography.labelSmall,
                                                            color = Accent.copy(alpha = DS.Opacity.m)
                                                        )
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            },
                            navigationIcon = {
                                if (showSettings) {
                                    IconButton(onClick = { showSettings = false }) {
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
                                if (!showSettings) {
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
                    val envId = environmentStore.activeEnvironmentId.value ?: ""
                    val defaultDir = connectionManager.connection(envId)
                        ?.defaultWorkingDirectory?.collectAsState()?.value ?: "/"

                    when {
                        showSettings -> SettingsScreen(
                            environmentStore = environmentStore,
                            connectionManager = connectionManager,
                            currentTheme = appTheme,
                            onThemeChange = {
                                appTheme = it
                                prefs.edit().putString("theme", it.name).apply()
                            },
                            debugOverlayEnabled = debugOverlayEnabled,
                            onDebugOverlayChange = {
                                debugOverlayEnabled = it
                                prefs.edit().putBoolean("debugOverlay", it).apply()
                            },
                            modifier = Modifier.padding(innerPadding)
                        )
                        else -> MainScreen(
                            windowManager = windowManager,
                            viewModel = chatViewModel,
                            connectionManager = connectionManager,
                            environmentId = envId,
                            workingDirectory = defaultDir,
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

                    if (showRename) {
                        RenameDialog(
                            currentName = conversation.name,
                            onConfirm = { chatViewModel.renameConversation(it) },
                            onDismiss = { showRename = false }
                        )
                    }

                    if (showIconPicker) {
                        IconPickerSheet(
                            selectedIcon = conversation.symbol,
                            onSelect = { chatViewModel.setSymbol(it) },
                            onDismiss = { showIconPicker = false }
                        )
                    }

                    val shouldShowSkills by chatViewModel.showSkills.collectAsState()
                    if (shouldShowSkills) {
                        val skillsList by connectionManager.connection(envId)?.skills?.collectAsState()
                            ?: remember { mutableStateOf(emptyList()) }
                        SkillsSheet(
                            skills = skillsList,
                            onSelect = { command ->
                                chatViewModel.dismissSkills()
                            },
                            onDismiss = { chatViewModel.dismissSkills() }
                        )
                    }

                    val showWhiteboard by chatViewModel.showWhiteboard.collectAsState()
                    if (showWhiteboard) {
                        val wbState by chatViewModel.whiteboardState.collectAsState()
                        WhiteboardSheet(
                            state = wbState,
                            onStateChange = { chatViewModel.updateWhiteboardState(it) },
                            onDismiss = { chatViewModel.dismissWhiteboard() }
                        )
                    }

                    if (debugOverlayEnabled) {
                        Box(modifier = Modifier.fillMaxSize()) {
                            DebugOverlay(
                                connectionManager = connectionManager,
                                environmentId = envId
                            )
                        }
                    }
                }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        intent.data?.let { deepLinkRouter.handle(it) }
    }

    private fun triggerHaptic(style: String) {
        val vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            (getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager).defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
        }
        val effect = when (style) {
            "light" -> VibrationEffect.createOneShot(30, 80)
            "heavy" -> VibrationEffect.createOneShot(80, 255)
            "rigid" -> VibrationEffect.createOneShot(20, 255)
            "soft" -> VibrationEffect.createOneShot(50, 40)
            else -> VibrationEffect.createOneShot(50, 150)
        }
        vibrator.vibrate(effect)
    }

    private fun captureScreenshot(conversationId: String?) {
        val rootView = window.decorView.rootView
        rootView.post {
            val bitmap = Bitmap.createBitmap(rootView.width, rootView.height, Bitmap.Config.ARGB_8888)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                PixelCopy.request(window, bitmap, { result ->
                    if (result == PixelCopy.SUCCESS) sendScreenshot(bitmap, conversationId)
                }, android.os.Handler(mainLooper))
            } else {
                @Suppress("DEPRECATION")
                rootView.isDrawingCacheEnabled = true
                @Suppress("DEPRECATION")
                rootView.drawingCache?.let { sendScreenshot(it, conversationId) }
                @Suppress("DEPRECATION")
                rootView.isDrawingCacheEnabled = false
            }
        }
    }

    private fun sendScreenshot(bitmap: Bitmap, conversationId: String?) {
        val stream = java.io.ByteArrayOutputStream()
        bitmap.compress(Bitmap.CompressFormat.JPEG, 70, stream)
        val base64 = Base64.encodeToString(stream.toByteArray(), Base64.NO_WRAP)
        chatViewModel.sendMessage("[screenshot]", imagesBase64 = listOf(base64))
    }
}

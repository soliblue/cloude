package com.cloude.app.UI.chat

import android.content.Intent
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.clickable
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Folder
import androidx.compose.material3.Icon
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.style.TextOverflow
import com.cloude.app.Services.ChatViewModel
import com.cloude.app.Services.ConnectionManager
import com.cloude.app.Utilities.Accent
import com.cloude.app.Utilities.DS

@OptIn(ExperimentalLayoutApi::class)
@Composable
fun ChatScreen(
    viewModel: ChatViewModel,
    connectionManager: ConnectionManager,
    environmentId: String,
    initialDraft: String = "",
    onDraftChange: (String) -> Unit = {},
    modifier: Modifier = Modifier
) {
    val context = LocalContext.current
    val skills by connectionManager.connection(environmentId)?.skills?.collectAsState()
        ?: remember { mutableStateOf(emptyList()) }
    val whisperReady by connectionManager.connection(environmentId)?.whisperReady?.collectAsState()
        ?: remember { mutableStateOf(false) }
    val isTranscribing by viewModel.isTranscribing.collectAsState()
    val pendingTranscription by viewModel.pendingTranscription.collectAsState()
    val fileSearchResults by viewModel.fileSearchResults.collectAsState()
    val conversation by viewModel.conversation.collectAsState()
    val output = remember(conversation.id) { connectionManager.output(conversation.id) }
    val streamingText by output.text.collectAsState()
    val streamingTools by output.toolCalls.collectAsState()
    val isRunning by output.isRunning.collectAsState()
    val isCompacting by output.isCompacting.collectAsState()
    val messageCount = conversation.messages.size
    val queuedCount = conversation.pendingMessages.size
    val hasStreaming = streamingText.isNotEmpty() || streamingTools.isNotEmpty()
    val itemCount = 1 + messageCount + (if (hasStreaming) 1 else 0) + queuedCount + 1
    val listState = rememberLazyListState(initialFirstVisibleItemIndex = maxOf(0, itemCount - 1))
    var lastConversationId by remember { mutableStateOf(conversation.id) }

    LaunchedEffect(conversation.id) {
        if (conversation.id != lastConversationId) {
            lastConversationId = conversation.id
            if (itemCount > 1) listState.scrollToItem(itemCount - 1)
        }
    }

    LaunchedEffect(messageCount, queuedCount, streamingText, streamingTools.size) {
        if (itemCount > 2 && conversation.id == lastConversationId) {
            listState.animateScrollToItem(itemCount - 1)
        }
    }

    Column(
        modifier = modifier
            .fillMaxSize()
            .background(MaterialTheme.colorScheme.background)
    ) {
        if (isCompacting) {
            LinearProgressIndicator(
                modifier = Modifier.fillMaxWidth(),
                color = Accent
            )
        }

        if (itemCount > 3) {
            val scrollProgress = remember(listState.firstVisibleItemIndex, listState.firstVisibleItemScrollOffset, itemCount) {
                if (itemCount <= 1) 1f
                else (listState.firstVisibleItemIndex.toFloat() / (itemCount - 1).toFloat()).coerceIn(0f, 1f)
            }
            val isAtBottom = listState.firstVisibleItemIndex >= itemCount - 3
            LinearProgressIndicator(
                progress = { scrollProgress },
                modifier = Modifier
                    .fillMaxWidth()
                    .alpha(if (isAtBottom) 0f else 0.4f),
                color = Accent.copy(alpha = 0.5f),
                trackColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.3f)
            )
        }

        if (conversation.messages.isEmpty() && streamingText.isEmpty()) {
            var showFolderPicker by remember { mutableStateOf(false) }
            val workingDir = conversation.workingDirectory
                ?: connectionManager.connection(environmentId)?.defaultWorkingDirectory?.collectAsState()?.value
            val displayPath = workingDir?.substringAfterLast("/") ?: "No folder selected"

            Box(
                modifier = Modifier
                    .weight(1f)
                    .fillMaxWidth(),
                contentAlignment = Alignment.Center
            ) {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Text(
                        text = "Cloude",
                        style = MaterialTheme.typography.headlineMedium,
                        color = MaterialTheme.colorScheme.onBackground.copy(alpha = DS.Opacity.m)
                    )
                    Spacer(modifier = Modifier.height(DS.Spacing.l))
                    Row(
                        modifier = Modifier
                            .clip(RoundedCornerShape(DS.Radius.l))
                            .background(MaterialTheme.colorScheme.surfaceVariant)
                            .clickable { showFolderPicker = true }
                            .padding(horizontal = DS.Spacing.m, vertical = DS.Spacing.s),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(DS.Spacing.s)
                    ) {
                        Icon(
                            Icons.Default.Folder,
                            null,
                            tint = Accent,
                            modifier = Modifier.size(DS.Icon.m)
                        )
                        Text(
                            text = displayPath,
                            style = MaterialTheme.typography.bodyMedium,
                            color = MaterialTheme.colorScheme.onSurface,
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis
                        )
                    }
                    if (workingDir != null) {
                        Text(
                            text = workingDir,
                            style = MaterialTheme.typography.labelSmall,
                            color = MaterialTheme.colorScheme.onSurface.copy(alpha = DS.Opacity.m),
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis,
                            modifier = Modifier.padding(top = DS.Spacing.xs)
                        )
                    }
                }
            }

            if (showFolderPicker) {
                FolderPickerSheet(
                    connectionManager = connectionManager,
                    environmentId = environmentId,
                    initialPath = workingDir ?: "/",
                    onSelect = { viewModel.setWorkingDirectory(it) },
                    onDismiss = { showFolderPicker = false }
                )
            }
        } else {
            LazyColumn(
                modifier = Modifier
                    .weight(1f)
                    .fillMaxWidth()
                    .padding(horizontal = DS.Spacing.s),
                state = listState,
                verticalArrangement = Arrangement.spacedBy(DS.Spacing.m)
            ) {
                item { Spacer(modifier = Modifier.height(DS.Spacing.s)) }

                items(conversation.messages, key = { it.id }) { message ->
                    MessageBubble(
                        message = message,
                        onToggleCollapse = if (!message.isUser) {{ viewModel.toggleCollapse(message.id) }} else null,
                        onFork = if (conversation.sessionId != null) {{ viewModel.forkConversation(message.id) }} else null
                    )
                }

                if (streamingText.isNotEmpty() || streamingTools.isNotEmpty()) {
                    item(key = "streaming") {
                        Column(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(start = DS.Spacing.xs, end = DS.Spacing.xxl)
                        ) {
                            if (streamingTools.isNotEmpty()) {
                                val regularTools = streamingTools.filter { !isWidget(it.name) }
                                val widgetTools = streamingTools.filter { isWidget(it.name) }

                                if (regularTools.isNotEmpty()) {
                                    FlowRow(
                                        modifier = Modifier.padding(bottom = DS.Spacing.xs),
                                        horizontalArrangement = Arrangement.spacedBy(DS.Spacing.xs),
                                        verticalArrangement = Arrangement.spacedBy(DS.Spacing.xs)
                                    ) {
                                        regularTools.forEach { toolCall ->
                                            ToolCallLabel(toolCall = toolCall)
                                        }
                                    }
                                }

                                widgetTools.forEach { toolCall ->
                                    WidgetView(toolName = toolCall.name, inputJson = toolCall.input)
                                    Spacer(modifier = Modifier.height(DS.Spacing.xs))
                                }
                            }
                            if (streamingText.isNotEmpty()) {
                                MarkdownText(
                                    text = streamingText,
                                    color = MaterialTheme.colorScheme.onSurface,
                                    modifier = Modifier
                                        .background(
                                            MaterialTheme.colorScheme.surfaceVariant,
                                            RoundedCornerShape(DS.Radius.l)
                                        )
                                        .padding(horizontal = DS.Spacing.m, vertical = DS.Spacing.s)
                                )
                            }
                        }
                    }
                }

                if (conversation.pendingMessages.isNotEmpty()) {
                    items(conversation.pendingMessages, key = { "queued-${it.id}" }) { message ->
                        Box(modifier = Modifier.alpha(DS.Opacity.l)) {
                            MessageBubble(message = message)
                        }
                    }
                }

                item { Spacer(modifier = Modifier.height(DS.Spacing.s)) }
            }
        }

        InputBar(
            isRunning = isRunning,
            isTranscribing = isTranscribing,
            whisperReady = whisperReady,
            pendingTranscription = pendingTranscription,
            currentEffort = conversation.defaultEffort,
            currentModel = conversation.defaultModel,
            skills = skills,
            fileSearchResults = fileSearchResults,
            workingDirectory = conversation.workingDirectory
                ?: connectionManager.connection(environmentId)?.defaultWorkingDirectory?.value,
            initialDraft = initialDraft,
            onDraftChange = onDraftChange,
            onSend = { text, images, files ->
                when {
                    text.trim().equals("/usage", ignoreCase = true) -> viewModel.requestUsageStats()
                    text.trim().equals("/plans", ignoreCase = true) -> viewModel.requestPlans()
                    text.trim().equals("/skills", ignoreCase = true) -> viewModel.showSkills()
                    text.trim().equals("/test-widgets", ignoreCase = true) -> viewModel.injectTestWidgets()
                    text.trim().equals("/export", ignoreCase = true) -> {
                        val markdown = viewModel.exportConversation()
                        val intent = Intent(Intent.ACTION_SEND).apply {
                            type = "text/plain"
                            putExtra(Intent.EXTRA_TEXT, markdown)
                        }
                        context.startActivity(Intent.createChooser(intent, "Export conversation"))
                    }
                    else -> viewModel.sendMessage(text, images, files)
                }
            },
            onAbort = { viewModel.abort() },
            onTranscribe = { viewModel.transcribe(it) },
            onTranscriptionConsumed = { viewModel.consumeTranscription() },
            onEffortChange = { viewModel.setEffort(it) },
            onModelChange = { viewModel.setModel(it) },
            onFileSearch = { viewModel.searchFiles(it) },
            onFileSearchClear = { viewModel.clearFileSearchResults() },
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = DS.Spacing.m, vertical = DS.Spacing.s)
        )
    }
}

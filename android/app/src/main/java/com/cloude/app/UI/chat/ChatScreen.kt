package com.cloude.app.UI.chat

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
import androidx.compose.ui.draw.clip
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
    modifier: Modifier = Modifier
) {
    val skills by connectionManager.connection(environmentId)?.skills?.collectAsState()
        ?: remember { mutableStateOf(emptyList()) }
    val conversation by viewModel.conversation.collectAsState()
    val streamingText by viewModel.output.text.collectAsState()
    val streamingTools by viewModel.output.toolCalls.collectAsState()
    val isRunning by viewModel.output.isRunning.collectAsState()
    val isCompacting by viewModel.output.isCompacting.collectAsState()
    val messageCount = conversation.messages.size
    val hasStreaming = streamingText.isNotEmpty() || streamingTools.isNotEmpty()
    val itemCount = 1 + messageCount + (if (hasStreaming) 1 else 0) + 1
    val listState = rememberLazyListState(initialFirstVisibleItemIndex = maxOf(0, itemCount - 1))

    LaunchedEffect(messageCount, streamingText) {
        if (itemCount > 2) listState.animateScrollToItem(itemCount - 1)
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
                    MessageBubble(message = message)
                }

                if (streamingText.isNotEmpty() || streamingTools.isNotEmpty()) {
                    item(key = "streaming") {
                        Column(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(start = DS.Spacing.xs, end = DS.Spacing.xxl)
                        ) {
                            if (streamingTools.isNotEmpty()) {
                                FlowRow(
                                    modifier = Modifier.padding(bottom = DS.Spacing.xs),
                                    horizontalArrangement = Arrangement.spacedBy(DS.Spacing.xs),
                                    verticalArrangement = Arrangement.spacedBy(DS.Spacing.xs)
                                ) {
                                    streamingTools.forEach { toolCall ->
                                        ToolCallLabel(toolCall = toolCall)
                                    }
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

                item { Spacer(modifier = Modifier.height(DS.Spacing.s)) }
            }
        }

        InputBar(
            isRunning = isRunning,
            currentEffort = conversation.defaultEffort,
            currentModel = conversation.defaultModel,
            skills = skills,
            onSend = { text, images -> viewModel.sendMessage(text, images) },
            onAbort = { viewModel.abort() },
            onEffortChange = { viewModel.setEffort(it) },
            onModelChange = { viewModel.setModel(it) },
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = DS.Spacing.m, vertical = DS.Spacing.s)
        )
    }
}

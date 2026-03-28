package com.cloude.app.UI.chat

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import com.cloude.app.Services.ChatViewModel
import com.cloude.app.Utilities.Accent
import com.cloude.app.Utilities.DS

@OptIn(ExperimentalLayoutApi::class)
@Composable
fun ChatScreen(viewModel: ChatViewModel, modifier: Modifier = Modifier) {
    val conversation by viewModel.conversation.collectAsState()
    val streamingText by viewModel.output.text.collectAsState()
    val streamingTools by viewModel.output.toolCalls.collectAsState()
    val isRunning by viewModel.output.isRunning.collectAsState()
    val isCompacting by viewModel.output.isCompacting.collectAsState()
    val listState = rememberLazyListState()

    LaunchedEffect(conversation.messages.size, streamingText) {
        val total = conversation.messages.size + (if (streamingText.isNotEmpty() || streamingTools.isNotEmpty()) 1 else 0)
        if (total > 0) listState.animateScrollToItem(total - 1)
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
            Box(
                modifier = Modifier
                    .weight(1f)
                    .fillMaxWidth(),
                contentAlignment = Alignment.Center
            ) {
                Text(
                    text = "Cloude",
                    style = MaterialTheme.typography.headlineMedium,
                    color = MaterialTheme.colorScheme.onBackground.copy(alpha = DS.Opacity.m)
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
            onSend = { viewModel.sendMessage(it) },
            onAbort = { viewModel.abort() },
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = DS.Spacing.m, vertical = DS.Spacing.s)
        )
    }
}

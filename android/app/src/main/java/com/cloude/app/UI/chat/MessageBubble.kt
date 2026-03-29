package com.cloude.app.UI.chat

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.indication
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.selection.SelectionContainer
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.TextSnippet
import androidx.compose.material.icons.filled.ContentCopy
import androidx.compose.material.icons.filled.UnfoldLess
import androidx.compose.material.icons.filled.UnfoldMore
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.cloude.app.Models.ChatMessage
import com.cloude.app.Utilities.Accent
import com.cloude.app.Utilities.DS

private val COLLAPSED_MAX_HEIGHT = 120.dp

@OptIn(ExperimentalLayoutApi::class, ExperimentalFoundationApi::class, ExperimentalMaterial3Api::class)
@Composable
fun MessageBubble(
    message: ChatMessage,
    onToggleCollapse: (() -> Unit)? = null,
    modifier: Modifier = Modifier
) {
    val context = LocalContext.current
    val interactionSource = remember { MutableInteractionSource() }
    var showMenu by remember { mutableStateOf(false) }
    var showTextSelection by remember { mutableStateOf(false) }
    val bubbleBackground = if (message.wasInterrupted && !message.isUser) {
        Accent.copy(alpha = 0.15f)
    } else if (message.isUser) {
        Accent.copy(alpha = 0.85f)
    } else {
        MaterialTheme.colorScheme.surfaceVariant
    }

    Column(
        modifier = modifier
            .fillMaxWidth()
            .padding(
                start = if (message.isUser) DS.Spacing.xxl else DS.Spacing.xs,
                end = if (message.isUser) DS.Spacing.xs else DS.Spacing.xxl
            )
    ) {
        if (message.toolCalls.isNotEmpty()) {
            FlowRow(
                modifier = Modifier.padding(bottom = DS.Spacing.xs),
                horizontalArrangement = Arrangement.spacedBy(DS.Spacing.xs),
                verticalArrangement = Arrangement.spacedBy(DS.Spacing.xs)
            ) {
                message.toolCalls.forEach { toolCall ->
                    ToolCallLabel(toolCall = toolCall)
                }
            }
        }

        if ((message.imageCount > 0 || message.fileCount > 0) && message.isUser) {
            val parts = mutableListOf<String>()
            if (message.imageCount > 0) parts.add("\uD83D\uDDBC ${message.imageCount} image${if (message.imageCount > 1) "s" else ""}")
            if (message.fileCount > 0) parts.add("\uD83D\uDCCE ${message.fileCount} file${if (message.fileCount > 1) "s" else ""}")
            Text(
                text = "${parts.joinToString("  ")} attached",
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = DS.Opacity.m),
                textAlign = TextAlign.End,
                modifier = Modifier.fillMaxWidth().padding(bottom = DS.Spacing.xs)
            )
        }

        if (message.text.isNotEmpty()) {
            Box {
                if (message.isUser) {
                    Text(
                        text = message.text,
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onPrimary,
                        textAlign = TextAlign.End,
                        modifier = Modifier
                            .fillMaxWidth()
                            .clip(RoundedCornerShape(DS.Radius.l))
                            .background(bubbleBackground)
                            .combinedClickable(
                                onClick = {},
                                onLongClick = { showMenu = true }
                            )
                            .padding(horizontal = DS.Spacing.m, vertical = DS.Spacing.s)
                    )
                } else {
                    Column {
                        Box(
                            modifier = Modifier
                                .fillMaxWidth()
                                .then(
                                    if (message.isCollapsed) Modifier.heightIn(max = COLLAPSED_MAX_HEIGHT)
                                    else Modifier
                                )
                                .clip(RoundedCornerShape(DS.Radius.l))
                                .background(bubbleBackground)
                                .indication(interactionSource, androidx.compose.material3.ripple())
                                .combinedClickable(
                                    interactionSource = interactionSource,
                                    indication = null,
                                    onClick = {},
                                    onLongClick = { showMenu = true }
                                )
                                .padding(horizontal = DS.Spacing.m, vertical = DS.Spacing.s)
                        ) {
                            MarkdownText(
                                text = message.text,
                                color = MaterialTheme.colorScheme.onSurface,
                                onLongPress = { showMenu = true },
                                interactionSource = interactionSource,
                            )

                            if (message.isCollapsed) {
                                Box(
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .heightIn(min = 40.dp)
                                        .background(
                                            Brush.verticalGradient(
                                                colors = listOf(
                                                    Color.Transparent,
                                                    bubbleBackground
                                                )
                                            )
                                        )
                                        .align(Alignment.BottomCenter)
                                )
                            }
                        }

                        if (message.isCollapsed) {
                            Text(
                                text = "Show more",
                                style = MaterialTheme.typography.labelMedium,
                                color = MaterialTheme.colorScheme.onSurface.copy(alpha = DS.Opacity.m),
                                textAlign = TextAlign.Center,
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .combinedClickable(onClick = { onToggleCollapse?.invoke() })
                                    .padding(top = DS.Spacing.xs)
                            )
                        }
                    }
                }

                DropdownMenu(expanded = showMenu, onDismissRequest = { showMenu = false }) {
                    DropdownMenuItem(
                        text = { Text("Copy") },
                        leadingIcon = { Icon(Icons.Default.ContentCopy, contentDescription = null) },
                        onClick = {
                            val clipboard = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
                            clipboard.setPrimaryClip(ClipData.newPlainText("message", message.text))
                            showMenu = false
                        }
                    )
                    DropdownMenuItem(
                        text = { Text("Select Text") },
                        leadingIcon = { Icon(Icons.AutoMirrored.Filled.TextSnippet, contentDescription = null) },
                        onClick = {
                            showTextSelection = true
                            showMenu = false
                        }
                    )
                    if (!message.isUser && onToggleCollapse != null) {
                        DropdownMenuItem(
                            text = { Text(if (message.isCollapsed) "Expand" else "Collapse") },
                            leadingIcon = {
                                Icon(
                                    if (message.isCollapsed) Icons.Default.UnfoldMore else Icons.Default.UnfoldLess,
                                    contentDescription = null
                                )
                            },
                            onClick = {
                                onToggleCollapse.invoke()
                                showMenu = false
                            }
                        )
                    }
                }
            }
        }

        if (showTextSelection) {
            ModalBottomSheet(
                onDismissRequest = { showTextSelection = false },
                sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
            ) {
                SelectionContainer {
                    Text(
                        text = message.text,
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurface,
                        modifier = Modifier
                            .fillMaxWidth()
                            .verticalScroll(rememberScrollState())
                            .padding(horizontal = DS.Spacing.l, vertical = DS.Spacing.m)
                    )
                }
            }
        }

        if (message.wasInterrupted && !message.isUser) {
            Text(
                text = "interrupted",
                style = MaterialTheme.typography.labelSmall,
                color = Accent.copy(alpha = DS.Opacity.m),
                modifier = Modifier.padding(top = DS.Spacing.xs)
            )
        }

        if (message.costUsd != null) {
            Row(
                modifier = Modifier.padding(top = DS.Spacing.xs),
                horizontalArrangement = Arrangement.spacedBy(DS.Spacing.s)
            ) {
                message.model?.let {
                    Text(
                        text = it,
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.onSurface.copy(alpha = DS.Opacity.m)
                    )
                }
                Text(
                    text = "$${String.format("%.4f", message.costUsd)}",
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = DS.Opacity.m)
                )
            }
        }
    }
}

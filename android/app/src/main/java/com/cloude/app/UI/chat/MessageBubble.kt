package com.cloude.app.UI.chat

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.graphics.BitmapFactory
import android.util.Base64
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.Image
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
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.gestures.rememberTransformableState
import androidx.compose.foundation.gestures.transformable
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.selection.SelectionContainer
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.TextSnippet
import androidx.compose.material.icons.filled.ContentCopy
import androidx.compose.material.icons.filled.ForkRight
import androidx.compose.material.icons.filled.Info
import androidx.compose.material.icons.filled.Schedule
import androidx.compose.material.icons.filled.UnfoldLess
import androidx.compose.material.icons.filled.UnfoldMore
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import com.cloude.app.Models.ChatMessage
import com.cloude.app.Utilities.Accent
import com.cloude.app.Utilities.DS

private val SLASH_CMD_RE = Regex("^/([a-zA-Z][a-zA-Z0-9_-]*)(?:\\s+(.+))?$", RegexOption.DOT_MATCHES_ALL)

private fun slashCommandIcon(name: String): String = when (name) {
    "compact" -> "\u21BB"
    "context" -> "\u25CF"
    "cost" -> "$"
    "clear" -> "\u2715"
    else -> "\u2726"
}

private val COLLAPSED_MAX_HEIGHT = 120.dp

@OptIn(ExperimentalLayoutApi::class, ExperimentalFoundationApi::class, ExperimentalMaterial3Api::class)
@Composable
fun MessageBubble(
    message: ChatMessage,
    onToggleCollapse: (() -> Unit)? = null,
    onFork: (() -> Unit)? = null,
    onFilePathTap: ((String) -> Unit)? = null,
    modifier: Modifier = Modifier
) {
    val context = LocalContext.current
    val interactionSource = remember { MutableInteractionSource() }
    var showMenu by remember { mutableStateOf(false) }
    var showTextSelection by remember { mutableStateOf(false) }
    var showInfo by remember { mutableStateOf(false) }
    var expandedImageIndex by remember { mutableStateOf(-1) }
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
            val regularTools = message.toolCalls.filter { !isWidget(it.name) }
            val widgetTools = message.toolCalls.filter { isWidget(it.name) }

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
                WidgetView(
                    toolName = toolCall.name,
                    inputJson = toolCall.input
                )
                Spacer(modifier = Modifier.height(DS.Spacing.xs))
            }
        }

        if (message.isUser && !message.imageThumbnails.isNullOrEmpty()) {
            Row(
                modifier = Modifier.fillMaxWidth().padding(bottom = DS.Spacing.xs),
                horizontalArrangement = Arrangement.spacedBy(DS.Spacing.xs, Alignment.End)
            ) {
                message.imageThumbnails!!.forEachIndexed { index, thumbBase64 ->
                    val bytes = remember(thumbBase64) { Base64.decode(thumbBase64, Base64.DEFAULT) }
                    val bitmap = remember(thumbBase64) { BitmapFactory.decodeByteArray(bytes, 0, bytes.size) }
                    if (bitmap != null) {
                        Image(
                            bitmap = bitmap.asImageBitmap(),
                            contentDescription = "Attached image",
                            contentScale = ContentScale.Crop,
                            modifier = Modifier
                                .size(DS.Size.l)
                                .clip(RoundedCornerShape(DS.Radius.s))
                                .clickable { expandedImageIndex = index }
                        )
                    }
                }
            }
        } else if (message.isUser && (message.imageCount > 0 || message.fileCount > 0)) {
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
                    val slashMatch = SLASH_CMD_RE.matchEntire(message.text.trim())
                    if (slashMatch != null) {
                        val cmdName = slashMatch.groupValues[1]
                        val cmdArgs = slashMatch.groupValues[2].takeIf { it.isNotBlank() }
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .combinedClickable(onClick = {}, onLongClick = { showMenu = true }),
                            horizontalArrangement = Arrangement.End
                        ) {
                            Row(
                                modifier = Modifier
                                    .clip(RoundedCornerShape(DS.Radius.l))
                                    .background(Accent.copy(alpha = 0.15f))
                                    .padding(horizontal = DS.Spacing.m, vertical = DS.Spacing.s),
                                horizontalArrangement = Arrangement.spacedBy(DS.Spacing.xs),
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Text(
                                    text = slashCommandIcon(cmdName),
                                    style = MaterialTheme.typography.bodyMedium,
                                    color = Accent
                                )
                                Text(
                                    text = "/$cmdName",
                                    style = MaterialTheme.typography.bodyMedium.copy(
                                        fontFamily = FontFamily.Monospace,
                                        fontWeight = FontWeight.Medium
                                    ),
                                    color = Accent
                                )
                                if (cmdArgs != null) {
                                    Text(
                                        text = cmdArgs,
                                        style = MaterialTheme.typography.bodyMedium.copy(
                                            fontFamily = FontFamily.Monospace
                                        ),
                                        color = Accent.copy(alpha = DS.Opacity.m)
                                    )
                                }
                            }
                        }
                    } else {
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
                    }
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
                                onFilePathTap = onFilePathTap,
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
                    if (onFork != null) {
                        DropdownMenuItem(
                            text = { Text("Fork from here") },
                            leadingIcon = { Icon(Icons.Default.ForkRight, contentDescription = null) },
                            onClick = {
                                onFork.invoke()
                                showMenu = false
                            }
                        )
                    }
                    if (!message.isUser) {
                        DropdownMenuItem(
                            text = { Text("Info") },
                            leadingIcon = { Icon(Icons.Default.Info, contentDescription = null) },
                            onClick = {
                                showInfo = true
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

        if (expandedImageIndex >= 0) {
            val previewPath = message.imagePreviews?.getOrNull(expandedImageIndex)
            val fallbackBase64 = message.imageThumbnails?.getOrNull(expandedImageIndex)
            val fullBitmap = remember(previewPath, fallbackBase64) {
                if (previewPath != null) {
                    val file = java.io.File(previewPath)
                    if (file.exists()) BitmapFactory.decodeFile(previewPath)
                    else fallbackBase64?.let { b64 ->
                        val bytes = Base64.decode(b64, Base64.DEFAULT)
                        BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
                    }
                } else fallbackBase64?.let { b64 ->
                    val bytes = Base64.decode(b64, Base64.DEFAULT)
                    BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
                }
            }
            fullBitmap?.let { bmp ->
                Dialog(
                    onDismissRequest = { expandedImageIndex = -1 },
                    properties = DialogProperties(usePlatformDefaultWidth = false)
                ) {
                    var scale by remember { mutableFloatStateOf(1f) }
                    var offset by remember { mutableStateOf(Offset.Zero) }
                    val transformState = rememberTransformableState { zoomChange, panChange, _ ->
                        scale = (scale * zoomChange).coerceIn(1f, 5f)
                        offset = if (scale > 1f) offset + panChange else Offset.Zero
                    }

                    Box(
                        modifier = Modifier
                            .fillMaxSize()
                            .background(Color.Black)
                            .pointerInput(Unit) {
                                detectTapGestures(
                                    onTap = { expandedImageIndex = -1 },
                                    onDoubleTap = {
                                        scale = if (scale > 1.5f) 1f else 3f
                                        offset = Offset.Zero
                                    }
                                )
                            },
                        contentAlignment = Alignment.Center
                    ) {
                        Image(
                            bitmap = bmp.asImageBitmap(),
                            contentDescription = "Expanded image",
                            contentScale = ContentScale.Fit,
                            modifier = Modifier
                                .fillMaxSize()
                                .graphicsLayer(
                                    scaleX = scale,
                                    scaleY = scale,
                                    translationX = offset.x,
                                    translationY = offset.y
                                )
                                .transformable(state = transformState)
                        )
                    }
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

        if (message.isQueued) {
            Row(
                modifier = Modifier.padding(top = DS.Spacing.xs),
                horizontalArrangement = Arrangement.spacedBy(DS.Spacing.xs),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Icon(
                    imageVector = Icons.Default.Schedule,
                    contentDescription = null,
                    tint = MaterialTheme.colorScheme.onSurface.copy(alpha = DS.Opacity.m),
                    modifier = Modifier.size(DS.Icon.s)
                )
                Text(
                    text = "queued",
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = DS.Opacity.m)
                )
            }
        }

    }

    if (showInfo) {
        MessageInfoSheet(message = message, onDismiss = { showInfo = false })
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun MessageInfoSheet(message: ChatMessage, onDismiss: () -> Unit) {
    val sheetState = rememberModalBottomSheetState()

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
        containerColor = MaterialTheme.colorScheme.surfaceVariant
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = DS.Spacing.l, vertical = DS.Spacing.m),
            verticalArrangement = Arrangement.spacedBy(DS.Spacing.m)
        ) {
            Text(
                text = "Message Info",
                style = MaterialTheme.typography.titleMedium,
                color = MaterialTheme.colorScheme.onSurface
            )

            HorizontalDivider(color = MaterialTheme.colorScheme.outline.copy(alpha = 0.2f))

            message.model?.let {
                InfoRow("Model", it)
            }
            message.costUsd?.let {
                InfoRow("Cost", "$${String.format("%.4f", it)}")
            }
            message.durationMs?.let {
                val seconds = it / 1000.0
                InfoRow("Duration", "${String.format("%.1f", seconds)}s")
            }
            InfoRow("Characters", "${message.text.length}")
            if (message.toolCalls.isNotEmpty()) {
                InfoRow("Tool Calls", "${message.toolCalls.size}")
            }

            val date = java.text.SimpleDateFormat("MMM d, yyyy HH:mm:ss", java.util.Locale.getDefault())
                .format(java.util.Date(message.timestamp))
            InfoRow("Timestamp", date)

            Spacer(modifier = Modifier.height(DS.Spacing.l))
        }
    }
}

@Composable
private fun InfoRow(label: String, value: String) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween
    ) {
        Text(
            text = label,
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurface.copy(alpha = DS.Opacity.l)
        )
        Text(
            text = value,
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurface
        )
    }
}

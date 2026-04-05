package com.cloude.app.UI.files

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.InsertDriveFile
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.Code
import androidx.compose.material.icons.filled.DataObject
import androidx.compose.material.icons.filled.Description
import androidx.compose.material.icons.filled.Folder
import androidx.compose.material.icons.filled.FolderOpen
import androidx.compose.material.icons.filled.AudioFile
import androidx.compose.material.icons.filled.Image
import androidx.compose.material.icons.filled.VideoFile
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.style.TextOverflow
import android.graphics.BitmapFactory
import android.util.Base64
import androidx.compose.foundation.Image
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.cloude.app.Models.ClientMessage
import com.cloude.app.Models.FileEntry
import com.cloude.app.Models.ServerMessage
import com.cloude.app.Services.ConnectionManager
import com.cloude.app.Utilities.Accent
import com.cloude.app.Utilities.DS
import kotlinx.coroutines.async
import kotlinx.coroutines.flow.filterIsInstance
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.withTimeoutOrNull

private data class TreeNode(
    val entry: FileEntry,
    val depth: Int,
    val isExpanded: Boolean,
    val isLoading: Boolean
)

@Composable
fun FileBrowserScreen(
    connectionManager: ConnectionManager,
    environmentId: String,
    initialPath: String,
    modifier: Modifier = Modifier
) {
    val childEntries = remember { mutableStateMapOf<String, List<FileEntry>>() }
    var expandedPaths by remember { mutableStateOf(setOf<String>()) }
    var loadingPaths by remember { mutableStateOf(setOf<String>()) }
    var isInitialLoad by remember { mutableStateOf(true) }
    var selectedFile by remember { mutableStateOf<FileEntry?>(null) }
    var rootPath by remember { mutableStateOf(initialPath) }
    val isAuthenticated by connectionManager.connection(environmentId)?.isAuthenticated?.collectAsState()
        ?: remember { mutableStateOf(false) }

    LaunchedEffect(Unit) {
        connectionManager.events
            .filterIsInstance<ServerMessage.DirectoryListing>()
            .collect { listing ->
                val sorted = listing.entries.sortedWith(
                    compareByDescending<FileEntry> { it.isDirectory }.thenBy { it.name.lowercase() }
                )
                childEntries[listing.path] = sorted
                loadingPaths = loadingPaths - listing.path
                if (isInitialLoad) rootPath = listing.path
                isInitialLoad = false
            }
    }

    LaunchedEffect(initialPath, isAuthenticated) {
        if (isAuthenticated) {
            isInitialLoad = true
            childEntries.clear()
            connectionManager.send(ClientMessage.ListDirectory(initialPath), environmentId)
        }
    }

    val visibleNodes = remember(childEntries.toMap(), expandedPaths, loadingPaths, rootPath) {
        buildList {
            fun appendNodes(parentPath: String, depth: Int) {
                val entries = childEntries[parentPath] ?: return
                for (entry in entries) {
                    val expanded = entry.path in expandedPaths
                    val loading = entry.path in loadingPaths
                    add(TreeNode(entry, depth, expanded, loading))
                    if (entry.isDirectory && expanded) {
                        appendNodes(entry.path, depth + 1)
                    }
                }
            }
            appendNodes(rootPath, 0)
        }
    }

    Column(modifier = modifier.fillMaxSize().background(MaterialTheme.colorScheme.background)) {
        PathBar(path = rootPath, onNavigate = {})
        HorizontalDivider(color = MaterialTheme.colorScheme.outline.copy(alpha = 0.2f))

        if (isInitialLoad) {
            Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                CircularProgressIndicator(color = Accent, modifier = Modifier.size(DS.Size.m))
            }
        } else if (visibleNodes.isEmpty()) {
            Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                Text(
                    text = "Empty folder",
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = DS.Opacity.m)
                )
            }
        } else {
            LazyColumn(modifier = Modifier.fillMaxSize()) {
                items(visibleNodes, key = { it.entry.path }) { node ->
                    TreeRow(
                        node = node,
                        onClick = {
                            if (node.entry.isDirectory) {
                                if (node.isExpanded) {
                                    expandedPaths = expandedPaths - node.entry.path
                                } else {
                                    expandedPaths = expandedPaths + node.entry.path
                                    if (node.entry.path !in childEntries) {
                                        loadingPaths = loadingPaths + node.entry.path
                                        connectionManager.send(
                                            ClientMessage.ListDirectory(node.entry.path),
                                            environmentId
                                        )
                                    }
                                }
                            } else {
                                selectedFile = node.entry
                            }
                        }
                    )
                }
                item { Spacer(modifier = Modifier.height(DS.Spacing.l)) }
            }
        }
    }

    selectedFile?.let { file ->
        FileViewerSheet(
            file = file,
            connectionManager = connectionManager,
            environmentId = environmentId,
            onDismiss = { selectedFile = null }
        )
    }
}

@Composable
private fun PathBar(path: String, onNavigate: (String) -> Unit) {
    val components = remember(path) { buildPathComponents(path) }
    val scrollState = rememberScrollState()

    LaunchedEffect(path) { scrollState.animateScrollTo(scrollState.maxValue) }

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .horizontalScroll(scrollState)
            .padding(horizontal = DS.Spacing.m, vertical = DS.Spacing.s),
        verticalAlignment = Alignment.CenterVertically
    ) {
        components.forEachIndexed { index, (name, _) ->
            if (index > 0) {
                Icon(
                    imageVector = Icons.Default.ChevronRight,
                    contentDescription = null,
                    tint = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.3f),
                    modifier = Modifier.size(DS.Icon.s)
                )
            }
            Text(
                text = name,
                style = MaterialTheme.typography.labelMedium,
                color = if (index == components.lastIndex) MaterialTheme.colorScheme.onSurface else Accent
            )
        }
    }
}

@Composable
private fun TreeRow(node: TreeNode, onClick: () -> Unit) {
    val chevronRotation by animateFloatAsState(
        targetValue = if (node.isExpanded) 90f else 0f,
        label = "chevron"
    )

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick)
            .padding(start = DS.Spacing.l + (DS.Spacing.l * node.depth), end = DS.Spacing.l, top = DS.Spacing.s, bottom = DS.Spacing.s),
        verticalAlignment = Alignment.CenterVertically
    ) {
        if (node.entry.isDirectory) {
            if (node.isLoading) {
                CircularProgressIndicator(
                    color = Accent,
                    strokeWidth = 1.5.dp,
                    modifier = Modifier.size(DS.Icon.s)
                )
            } else {
                Icon(
                    imageVector = Icons.Default.ChevronRight,
                    contentDescription = null,
                    tint = MaterialTheme.colorScheme.onSurface.copy(alpha = DS.Opacity.l),
                    modifier = Modifier
                        .size(DS.Icon.s)
                        .rotate(chevronRotation)
                )
            }
            Spacer(modifier = Modifier.width(DS.Spacing.xs))
        } else {
            Spacer(modifier = Modifier.width(DS.Icon.s + DS.Spacing.xs))
        }

        Icon(
            imageVector = if (node.entry.isDirectory && node.isExpanded) Icons.Default.FolderOpen else fileIcon(node.entry),
            contentDescription = null,
            tint = fileIconColor(node.entry),
            modifier = Modifier.size(DS.Icon.l)
        )
        Spacer(modifier = Modifier.width(DS.Spacing.s))
        Text(
            text = node.entry.name,
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurface,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            modifier = Modifier.weight(1f)
        )
        if (!node.entry.isDirectory && node.entry.size != null) {
            Text(
                text = formatSize(node.entry.size),
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = DS.Opacity.m)
            )
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun FileViewerSheet(
    file: FileEntry,
    connectionManager: ConnectionManager,
    environmentId: String,
    onDismiss: () -> Unit
) {
    var rawBytes by remember { mutableStateOf<ByteArray?>(null) }
    var isLoading by remember { mutableStateOf(true) }
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    val ext = file.name.substringAfterLast('.', "").lowercase()
    val isAudio = ext in setOf("wav", "mp3", "m4a", "aac", "ogg", "flac")
    val isVideo = ext in setOf("mp4", "mov", "m4v", "avi", "webm")
    val isImage = ext in setOf("png", "jpg", "jpeg", "webp", "bmp", "ico")
    val isGif = ext == "gif"
    val isHtml = ext in setOf("html", "htm")

    LaunchedEffect(file.path) {
        val deferred = async {
            connectionManager.events
                .filterIsInstance<ServerMessage.FileContent>()
                .first { it.path == file.path }
        }
        connectionManager.send(ClientMessage.GetFile(file.path), environmentId)
        val result = withTimeoutOrNull(30_000L) { deferred.await() }
        rawBytes = if (result != null) {
            try { Base64.decode(result.data, Base64.DEFAULT) } catch (_: Exception) { null }
        } else null
        isLoading = false
    }

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
        containerColor = MaterialTheme.colorScheme.surfaceVariant
    ) {
        Column(modifier = Modifier.padding(bottom = DS.Spacing.xl)) {
            Text(
                text = file.name,
                style = MaterialTheme.typography.titleMedium,
                color = MaterialTheme.colorScheme.onSurface,
                modifier = Modifier.padding(horizontal = DS.Spacing.l, vertical = DS.Spacing.s)
            )
            HorizontalDivider(color = MaterialTheme.colorScheme.outline.copy(alpha = 0.2f))

            if (isLoading) {
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(DS.Spacing.xxl * 4),
                    contentAlignment = Alignment.Center
                ) {
                    CircularProgressIndicator(color = Accent, modifier = Modifier.size(DS.Size.m))
                }
            } else {
                val bytes = rawBytes
                val containerModifier = Modifier
                    .fillMaxWidth()
                    .padding(DS.Spacing.m)
                    .background(MaterialTheme.colorScheme.surface, RoundedCornerShape(DS.Radius.m))

                if (bytes == null) {
                    Box(
                        modifier = Modifier.fillMaxWidth().height(DS.Spacing.xxl * 4),
                        contentAlignment = Alignment.Center
                    ) {
                        Text(
                            text = "Unable to load file",
                            style = MaterialTheme.typography.bodyMedium,
                            color = MaterialTheme.colorScheme.error
                        )
                    }
                } else if (isImage) {
                    val bitmap = remember(bytes) { BitmapFactory.decodeByteArray(bytes, 0, bytes.size) }
                    if (bitmap != null) {
                        Image(
                            bitmap = bitmap.asImageBitmap(),
                            contentDescription = file.name,
                            contentScale = ContentScale.Fit,
                            modifier = containerModifier.padding(DS.Spacing.m)
                        )
                    } else {
                        Text(
                            text = "Unable to decode image",
                            style = MaterialTheme.typography.bodyMedium,
                            color = MaterialTheme.colorScheme.error,
                            modifier = containerModifier.padding(DS.Spacing.m)
                        )
                    }
                } else if (isGif) {
                    GifPreview(data = bytes, modifier = containerModifier.padding(DS.Spacing.m))
                } else if (isAudio) {
                    AudioPreview(data = bytes, fileName = file.name, modifier = containerModifier)
                } else if (isVideo) {
                    VideoPreview(data = bytes, fileName = file.name, modifier = containerModifier)
                } else if (ext == "pdf") {
                    PdfPreview(data = bytes, modifier = containerModifier)
                } else if (ext == "svg") {
                    SvgPreview(data = bytes, modifier = containerModifier)
                } else if (isHtml) {
                    HtmlPreview(data = bytes, modifier = containerModifier)
                } else {
                    val text = remember(bytes) {
                        try { String(bytes, Charsets.UTF_8) } catch (_: Exception) { "Unable to decode file" }
                    }
                    val language = SyntaxHighlighter.languageForPath(file.name)
                    val highlighted = remember(text, language) {
                        if (language != null) SyntaxHighlighter.highlight(text, language) else null
                    }
                    val scrollState = rememberScrollState()

                    when (ext) {
                        "json" -> JSONTreeViewer(
                            text = text,
                            modifier = containerModifier
                        )
                        "yaml", "yml" -> YAMLTreeViewer(
                            text = text,
                            modifier = containerModifier
                        )
                        "csv" -> CSVTableViewer(
                            text = text,
                            modifier = containerModifier
                        )
                        "tsv" -> CSVTableViewer(
                            text = text,
                            delimiter = '\t',
                            modifier = containerModifier
                        )
                        else -> {
                            val codeModifier = containerModifier
                                .padding(DS.Spacing.m)
                                .horizontalScroll(scrollState)
                            val codeStyle = MaterialTheme.typography.bodySmall.copy(
                                fontFamily = FontFamily.Monospace,
                                lineHeight = 18.sp
                            )
                            if (highlighted != null) {
                                Text(
                                    text = highlighted,
                                    style = codeStyle,
                                    modifier = codeModifier
                                )
                            } else {
                                Text(
                                    text = text,
                                    style = codeStyle,
                                    color = MaterialTheme.colorScheme.onSurface,
                                    modifier = codeModifier
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}

private fun buildPathComponents(path: String): List<Pair<String, String>> {
    val parts = path.split("/").filter { it.isNotEmpty() }
    return parts.mapIndexed { index, part ->
        val componentPath = "/" + parts.take(index + 1).joinToString("/")
        part to componentPath
    }
}

private fun fileIcon(entry: FileEntry): ImageVector {
    if (entry.isDirectory) return Icons.Default.Folder
    val ext = entry.name.substringAfterLast('.', "").lowercase()
    return when (ext) {
        "kt", "swift", "java", "py", "go", "rs", "ts", "js", "tsx", "jsx",
        "rb", "cpp", "c", "h", "cs", "php", "dart", "scala" -> Icons.Default.Code
        "json", "yaml", "yml", "toml", "xml", "plist" -> Icons.Default.DataObject
        "md", "txt", "rtf", "csv", "log" -> Icons.Default.Description
        "png", "jpg", "jpeg", "gif", "svg", "webp", "ico" -> Icons.Default.Image
        "wav", "mp3", "m4a", "aac", "ogg", "flac" -> Icons.Default.AudioFile
        "mp4", "mov", "m4v", "avi", "webm" -> Icons.Default.VideoFile
        else -> Icons.AutoMirrored.Filled.InsertDriveFile
    }
}

private fun fileIconColor(entry: FileEntry): Color {
    if (entry.isDirectory) return Color(0xFF64B5F6)
    val ext = entry.name.substringAfterLast('.', "").lowercase()
    return when (ext) {
        "kt" -> Color(0xFF7F52FF)
        "swift" -> Color(0xFFFF6B35)
        "py" -> Color(0xFFFFD43B)
        "go" -> Color(0xFF00ADD8)
        "rs" -> Color(0xFFDEA584)
        "ts", "tsx" -> Color(0xFF3178C6)
        "js", "jsx" -> Color(0xFFF7DF1E)
        "json" -> Color(0xFF9E9E9E)
        "yaml", "yml" -> Color(0xFFCB171E)
        "md" -> Color(0xFF42A5F5)
        "wav", "mp3", "m4a", "aac", "ogg", "flac" -> Color(0xFFE91E63)
        "mp4", "mov", "m4v", "avi", "webm" -> Color(0xFFFF5722)
        else -> Color(0xFF9E9E9E)
    }
}

private fun formatSize(bytes: Long): String = when {
    bytes < 1024 -> "${bytes}B"
    bytes < 1024 * 1024 -> "${bytes / 1024}KB"
    bytes < 1024 * 1024 * 1024 -> String.format("%.1fMB", bytes / (1024.0 * 1024))
    else -> String.format("%.1fGB", bytes / (1024.0 * 1024 * 1024))
}

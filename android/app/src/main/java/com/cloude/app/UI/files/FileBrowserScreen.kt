package com.cloude.app.UI.files

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
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
import androidx.compose.material.icons.filled.Image
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.style.TextOverflow
import android.util.Base64
import androidx.compose.ui.unit.sp
import com.cloude.app.Models.ClientMessage
import com.cloude.app.Models.FileEntry
import com.cloude.app.Models.ServerMessage
import com.cloude.app.Services.ConnectionManager
import com.cloude.app.Utilities.Accent
import com.cloude.app.Utilities.DS
import kotlinx.coroutines.flow.filterIsInstance

@Composable
fun FileBrowserScreen(
    connectionManager: ConnectionManager,
    environmentId: String,
    initialPath: String,
    modifier: Modifier = Modifier
) {
    var currentPath by remember { mutableStateOf(initialPath) }
    var entries by remember { mutableStateOf<List<FileEntry>>(emptyList()) }
    var isLoading by remember { mutableStateOf(true) }
    var selectedFile by remember { mutableStateOf<FileEntry?>(null) }

    LaunchedEffect(currentPath) {
        isLoading = true
        connectionManager.send(ClientMessage.ListDirectory(currentPath), environmentId)
    }

    LaunchedEffect(Unit) {
        connectionManager.events
            .filterIsInstance<ServerMessage.DirectoryListing>()
            .collect { listing ->
                currentPath = listing.path
                entries = listing.entries.sortedWith(
                    compareByDescending<FileEntry> { it.isDirectory }.thenBy { it.name.lowercase() }
                )
                isLoading = false
            }
    }

    Column(modifier = modifier.fillMaxSize().background(MaterialTheme.colorScheme.background)) {
        PathBar(
            path = currentPath,
            onNavigate = { currentPath = it }
        )
        HorizontalDivider(color = MaterialTheme.colorScheme.outline.copy(alpha = 0.2f))

        if (isLoading) {
            Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                CircularProgressIndicator(color = Accent, modifier = Modifier.size(DS.Size.m))
            }
        } else if (entries.isEmpty()) {
            Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                Text(
                    text = "Empty folder",
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = DS.Opacity.m)
                )
            }
        } else {
            LazyColumn(modifier = Modifier.fillMaxSize()) {
                items(entries, key = { it.path }) { entry ->
                    FileRow(
                        entry = entry,
                        onClick = {
                            if (entry.isDirectory) {
                                currentPath = entry.path
                            } else {
                                selectedFile = entry
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
        components.forEachIndexed { index, (name, componentPath) ->
            if (index > 0) {
                Icon(
                    imageVector = Icons.Default.ChevronRight,
                    contentDescription = null,
                    tint = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.3f),
                    modifier = Modifier.size(DS.Icon.s)
                )
            }
            val isLast = index == components.lastIndex
            Text(
                text = name,
                style = MaterialTheme.typography.labelMedium,
                color = if (isLast) MaterialTheme.colorScheme.onSurface else Accent,
                modifier = if (isLast) Modifier else Modifier.clickable { onNavigate(componentPath) }
            )
        }
    }
}

@Composable
private fun FileRow(entry: FileEntry, onClick: () -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick)
            .padding(horizontal = DS.Spacing.l, vertical = DS.Spacing.m),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Icon(
            imageVector = fileIcon(entry),
            contentDescription = null,
            tint = fileIconColor(entry),
            modifier = Modifier.size(DS.Icon.l)
        )
        Spacer(modifier = Modifier.width(DS.Spacing.m))
        Text(
            text = entry.name,
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurface,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            modifier = Modifier.weight(1f)
        )
        if (!entry.isDirectory && entry.size != null) {
            Text(
                text = formatSize(entry.size),
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = DS.Opacity.m)
            )
        }
        if (entry.isDirectory) {
            Icon(
                imageVector = Icons.Default.ChevronRight,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.3f),
                modifier = Modifier.size(DS.Icon.m)
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
    var content by remember { mutableStateOf<String?>(null) }
    var isLoading by remember { mutableStateOf(true) }
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)

    LaunchedEffect(file.path) {
        connectionManager.send(ClientMessage.GetFile(file.path), environmentId)
    }

    LaunchedEffect(file.path) {
        connectionManager.events
            .filterIsInstance<ServerMessage.FileContent>()
            .collect { fc ->
                if (fc.path == file.path) {
                    content = try {
                        String(Base64.decode(fc.data, Base64.DEFAULT))
                    } catch (_: Exception) {
                        fc.data
                    }
                    isLoading = false
                }
            }
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
                Text(
                    text = content ?: "Unable to load file",
                    style = MaterialTheme.typography.bodySmall.copy(
                        fontFamily = FontFamily.Monospace,
                        lineHeight = 18.sp
                    ),
                    color = MaterialTheme.colorScheme.onSurface,
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(DS.Spacing.m)
                        .background(
                            MaterialTheme.colorScheme.surface,
                            RoundedCornerShape(DS.Radius.m)
                        )
                        .padding(DS.Spacing.m)
                        .horizontalScroll(rememberScrollState())
                )
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
        "md" -> Color(0xFF42A5F5)
        else -> Color(0xFF9E9E9E)
    }
}

private fun formatSize(bytes: Long): String = when {
    bytes < 1024 -> "${bytes}B"
    bytes < 1024 * 1024 -> "${bytes / 1024}KB"
    bytes < 1024 * 1024 * 1024 -> String.format("%.1fMB", bytes / (1024.0 * 1024))
    else -> String.format("%.1fGB", bytes / (1024.0 * 1024 * 1024))
}

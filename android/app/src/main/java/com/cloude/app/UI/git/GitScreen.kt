package com.cloude.app.UI.git

import android.util.Log
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
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Folder
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.sp
import com.cloude.app.Models.ClientMessage
import com.cloude.app.Models.GitCommit
import com.cloude.app.Models.GitFileStatus
import com.cloude.app.Models.GitStatusInfo
import com.cloude.app.Models.ServerMessage
import com.cloude.app.Services.ConnectionManager
import com.cloude.app.Utilities.Accent
import com.cloude.app.Utilities.DS
import com.cloude.app.Utilities.PastelGreen
import com.cloude.app.Utilities.PastelRed
import kotlinx.coroutines.flow.filterIsInstance

@Composable
fun GitScreen(
    connectionManager: ConnectionManager,
    environmentId: String,
    workingDirectory: String,
    modifier: Modifier = Modifier
) {
    var status by remember { mutableStateOf<GitStatusInfo?>(null) }
    var recentCommits by remember { mutableStateOf<List<GitCommit>>(emptyList()) }
    var isLoading by remember { mutableStateOf(true) }
    var selectedFile by remember { mutableStateOf<GitFileStatus?>(null) }
    var diffText by remember { mutableStateOf<String?>(null) }
    var showCommitDialog by remember { mutableStateOf(false) }
    var commitResult by remember { mutableStateOf<String?>(null) }
    val selectedFiles = remember { mutableStateListOf<String>() }

    fun refresh() {
        isLoading = true
        connectionManager.send(ClientMessage.GitStatus(workingDirectory), environmentId)
    }

    LaunchedEffect(Unit) { refresh() }

    LaunchedEffect(Unit) {
        connectionManager.events.collect { msg ->
            when (msg) {
                is ServerMessage.GitStatusResult -> {
                    status = msg.status
                    isLoading = false
                    if (msg.status.files.isEmpty()) {
                        connectionManager.send(ClientMessage.GitLog(workingDirectory), environmentId)
                    }
                    msg.status.files.filter { it.path.endsWith("/") }.forEach { dir ->
                        val fullPath = if (dir.path.startsWith("/")) dir.path
                            else "$workingDirectory/${dir.path}"
                        connectionManager.send(ClientMessage.ListDirectory(fullPath), environmentId)
                    }
                }
                is ServerMessage.DirectoryListing -> {
                    val currentStatus = status ?: return@collect
                    val dirPath = msg.path.removePrefix(workingDirectory).removePrefix("/")
                    val folderEntry = currentStatus.files.firstOrNull { it.path.trimEnd('/') == dirPath.trimEnd('/') || it.path == "$dirPath/" }
                    if (folderEntry != null) {
                        val newFiles = currentStatus.files.toMutableList()
                        newFiles.remove(folderEntry)
                        msg.entries.filter { !it.isDirectory }.forEach { entry ->
                            val relativePath = entry.path.removePrefix(workingDirectory).removePrefix("/")
                            newFiles.add(GitFileStatus(path = relativePath, status = folderEntry.status))
                        }
                        msg.entries.filter { it.isDirectory }.forEach { entry ->
                            connectionManager.send(ClientMessage.ListDirectory(entry.path), environmentId)
                        }
                        status = currentStatus.copy(files = newFiles)
                    }
                }
                is ServerMessage.GitDiffResult -> {
                    Log.d("Cloude", "GitDiff received: path=${msg.path} len=${msg.diff.length}")
                    if (selectedFile != null) diffText = msg.diff
                }
                is ServerMessage.GitLogResult -> {
                    recentCommits = msg.commits
                }
                is ServerMessage.FileContent -> {
                    Log.d("Cloude", "FileContent in Git: path=${msg.path} selectedFile=${selectedFile?.path}")
                    if (selectedFile != null) {
                        val decoded = try {
                            String(android.util.Base64.decode(msg.data, android.util.Base64.DEFAULT))
                        } catch (_: Exception) { msg.data }
                        diffText = decoded.lines().joinToString("\n") { "+ $it" }
                    }
                }
                else -> {}
            }
        }
    }

    LaunchedEffect(Unit) {
        connectionManager.events
            .filterIsInstance<ServerMessage.GitCommitResult>()
            .collect {
                commitResult = if (it.success) "Committed successfully" else (it.message ?: "Commit failed")
                refresh()
            }
    }

    Column(modifier = modifier.fillMaxSize().background(MaterialTheme.colorScheme.background)) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = DS.Spacing.l, vertical = DS.Spacing.s),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Column {
                status?.let {
                    Text(
                        text = it.branch,
                        style = MaterialTheme.typography.titleMedium,
                        color = MaterialTheme.colorScheme.onSurface
                    )
                    val fileCount = it.files.size
                    val modCount = it.files.count { f -> f.status == "M" }
                    val newCount = fileCount - modCount
                    Text(
                        text = buildString {
                            append("$fileCount files")
                            if (modCount > 0) append(" \u00b7 $modCount modified")
                            if (newCount > 0) append(" \u00b7 $newCount new")
                            if (it.ahead > 0) append(" \u00b7 \u2191${it.ahead}")
                            if (it.behind > 0) append(" \u00b7 \u2193${it.behind}")
                        },
                        style = MaterialTheme.typography.labelSmall,
                        color = Accent
                    )
                }
            }
            Row(horizontalArrangement = Arrangement.spacedBy(DS.Spacing.xs)) {
                if (selectedFiles.isNotEmpty()) {
                    Button(
                        onClick = { showCommitDialog = true },
                        colors = ButtonDefaults.buttonColors(containerColor = Accent),
                        modifier = Modifier.height(DS.Size.m)
                    ) {
                        Text("Commit (${selectedFiles.size})", style = MaterialTheme.typography.labelSmall)
                    }
                }
                IconButton(onClick = { refresh() }) {
                    Icon(Icons.Default.Refresh, "Refresh", tint = Accent)
                }
            }
        }

        HorizontalDivider(color = MaterialTheme.colorScheme.outline.copy(alpha = 0.2f))

        if (isLoading) {
            Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                CircularProgressIndicator(color = Accent, modifier = Modifier.size(DS.Size.m))
            }
        } else if (status?.files.isNullOrEmpty()) {
            if (recentCommits.isEmpty()) {
                Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    Text(
                        text = "Working tree clean",
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurface.copy(alpha = DS.Opacity.m)
                    )
                }
            } else {
                LazyColumn(modifier = Modifier.fillMaxSize()) {
                    item {
                        Text(
                            text = "Recent Commits",
                            style = MaterialTheme.typography.labelSmall,
                            color = Accent,
                            modifier = Modifier.padding(start = DS.Spacing.l, top = DS.Spacing.m, bottom = DS.Spacing.xs)
                        )
                    }
                    items(recentCommits, key = { it.hash }) { commit ->
                        GitCommitRow(commit)
                    }
                    item { Spacer(modifier = Modifier.height(DS.Spacing.l)) }
                }
            }
        } else {
            LazyColumn(modifier = Modifier.fillMaxSize()) {
                items(status!!.files, key = { it.path }) { file ->
                    val isDir = file.path.endsWith("/")
                    GitFileRow(
                        file = file,
                        isSelected = file.path in selectedFiles,
                        isDirectory = isDir,
                        onToggle = {
                            if (isDir) return@GitFileRow
                            if (file.path in selectedFiles) selectedFiles.remove(file.path)
                            else selectedFiles.add(file.path)
                        },
                        onTapDiff = {
                            if (isDir) return@GitFileRow
                            selectedFile = file
                            diffText = null
                            if (file.status?.contains("?") == true) {
                                val fullPath = if (file.path.startsWith("/")) file.path
                                    else "$workingDirectory/${file.path}"
                                Log.d("Cloude", "Git GetFile for untracked: $fullPath")
                                connectionManager.send(
                                    ClientMessage.GetFile(fullPath),
                                    environmentId
                                )
                            } else {
                                connectionManager.send(
                                    ClientMessage.GitDiff(workingDirectory, file = file.path),
                                    environmentId
                                )
                            }
                        }
                    )
                }
                item { Spacer(modifier = Modifier.height(DS.Spacing.l)) }
            }
        }
    }

    selectedFile?.let { file ->
        DiffSheet(
            file = file,
            diff = diffText,
            onDismiss = { selectedFile = null; diffText = null }
        )
    }

    if (showCommitDialog) {
        CommitDialog(
            fileCount = selectedFiles.size,
            onCommit = { message ->
                connectionManager.send(
                    ClientMessage.GitCommit(workingDirectory, message, selectedFiles.toList()),
                    environmentId
                )
                selectedFiles.clear()
                showCommitDialog = false
            },
            onDismiss = { showCommitDialog = false }
        )
    }

    commitResult?.let { msg ->
        AlertDialog(
            onDismissRequest = { commitResult = null },
            confirmButton = { TextButton(onClick = { commitResult = null }) { Text("OK") } },
            text = { Text(msg) }
        )
    }
}

@Composable
private fun GitFileRow(
    file: GitFileStatus,
    isSelected: Boolean,
    isDirectory: Boolean = false,
    onToggle: () -> Unit,
    onTapDiff: () -> Unit
) {
    val statusCode = file.status ?: "?"
    val isUntracked = statusCode == "?"
    val statusColor = when {
        isUntracked -> PastelGreen
        statusCode == "M" -> Accent
        statusCode == "D" -> PastelRed
        statusCode == "R" -> Color(0xFF64B5F6)
        else -> MaterialTheme.colorScheme.onSurface.copy(alpha = DS.Opacity.m)
    }
    val statusLabel = when {
        isDirectory -> "new folder"
        statusCode == "M" -> "modified"
        statusCode == "A" -> "added"
        statusCode.contains("?") -> "new"
        statusCode == "D" -> "deleted"
        statusCode == "R" -> "renamed"
        else -> statusCode
    }

    val alpha = if (isDirectory) 0.5f else 1f

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .then(if (!isDirectory) Modifier.clickable(onClick = onTapDiff) else Modifier)
            .padding(horizontal = DS.Spacing.l, vertical = DS.Spacing.m),
        verticalAlignment = Alignment.CenterVertically
    ) {
        if (!isDirectory) {
            Box(
                modifier = Modifier
                    .size(22.dp)
                    .clip(RoundedCornerShape(DS.Radius.s))
                    .background(if (isSelected) Accent else MaterialTheme.colorScheme.surface)
                    .clickable(onClick = onToggle),
                contentAlignment = Alignment.Center
            ) {
                if (isSelected) {
                    Icon(Icons.Default.Check, null, tint = Color.White, modifier = Modifier.size(DS.Icon.s))
                }
            }
        } else {
            Icon(
                Icons.Default.Folder,
                null,
                tint = Color(0xFF64B5F6).copy(alpha = alpha),
                modifier = Modifier.size(22.dp)
            )
        }

        Spacer(modifier = Modifier.width(DS.Spacing.m))

        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = if (isDirectory) file.path else file.path.substringAfterLast("/"),
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = alpha)
            )
            if (!isDirectory) {
                Text(
                    text = file.path.substringBeforeLast("/", ""),
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = DS.Opacity.m),
                    maxLines = 1
                )
            }
        }

        Text(
            text = statusLabel,
            style = MaterialTheme.typography.labelSmall,
            color = statusColor,
            fontWeight = FontWeight.Bold
        )
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun DiffSheet(file: GitFileStatus, diff: String?, onDismiss: () -> Unit) {
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
        containerColor = MaterialTheme.colorScheme.surfaceVariant
    ) {
        Column(modifier = Modifier.padding(bottom = DS.Spacing.xl)) {
            Text(
                text = file.path.substringAfterLast("/"),
                style = MaterialTheme.typography.titleMedium,
                color = MaterialTheme.colorScheme.onSurface,
                modifier = Modifier.padding(horizontal = DS.Spacing.l, vertical = DS.Spacing.s)
            )
            Text(
                text = file.path,
                style = MaterialTheme.typography.labelSmall.copy(fontFamily = FontFamily.Monospace),
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = DS.Opacity.m),
                modifier = Modifier.padding(horizontal = DS.Spacing.l, vertical = DS.Spacing.xs)
            )

            HorizontalDivider(
                color = MaterialTheme.colorScheme.outline.copy(alpha = 0.2f),
                modifier = Modifier.padding(vertical = DS.Spacing.s)
            )

            if (diff == null) {
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(DS.Spacing.xxl * 4),
                    contentAlignment = Alignment.Center
                ) {
                    CircularProgressIndicator(color = Accent, modifier = Modifier.size(DS.Size.m))
                }
            } else if (diff.isEmpty()) {
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(DS.Spacing.l),
                    contentAlignment = Alignment.Center
                ) {
                    val msg = if (file.status?.contains("?") == true) "New untracked file" else "No changes"
                    Text(msg, color = MaterialTheme.colorScheme.onSurface.copy(alpha = DS.Opacity.m))
                }
            } else {
                LazyColumn(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = DS.Spacing.m)
                ) {
                    val lines = diff.lines()
                    items(lines.size) { index ->
                        val line = lines[index]
                        val bgColor = when {
                            line.startsWith("+") && !line.startsWith("+++") -> PastelGreen.copy(alpha = 0.1f)
                            line.startsWith("-") && !line.startsWith("---") -> PastelRed.copy(alpha = 0.1f)
                            line.startsWith("@@") -> Accent.copy(alpha = 0.1f)
                            else -> Color.Transparent
                        }
                        val textColor = when {
                            line.startsWith("+") && !line.startsWith("+++") -> PastelGreen
                            line.startsWith("-") && !line.startsWith("---") -> PastelRed
                            line.startsWith("@@") -> Accent
                            else -> MaterialTheme.colorScheme.onSurface.copy(alpha = 0.8f)
                        }
                        Text(
                            text = line,
                            style = MaterialTheme.typography.bodySmall.copy(
                                fontFamily = FontFamily.Monospace,
                                lineHeight = 16.sp
                            ),
                            color = textColor,
                            modifier = Modifier
                                .fillMaxWidth()
                                .background(bgColor)
                                .horizontalScroll(rememberScrollState())
                                .padding(horizontal = DS.Spacing.s, vertical = 1.dp)
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun CommitDialog(fileCount: Int, onCommit: (String) -> Unit, onDismiss: () -> Unit) {
    var message by remember { mutableStateOf("") }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("Commit $fileCount file${if (fileCount > 1) "s" else ""}") },
        text = {
            OutlinedTextField(
                value = message,
                onValueChange = { message = it },
                label = { Text("Commit message") },
                modifier = Modifier.fillMaxWidth(),
                minLines = 2
            )
        },
        confirmButton = {
            TextButton(
                onClick = { onCommit(message) },
                enabled = message.isNotBlank()
            ) { Text("Commit", color = if (message.isNotBlank()) Accent else Color.Gray) }
        },
        dismissButton = { TextButton(onClick = onDismiss) { Text("Cancel") } }
    )
}

@Composable
private fun GitCommitRow(commit: GitCommit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = DS.Spacing.l, vertical = DS.Spacing.s),
        verticalAlignment = Alignment.Top
    ) {
        Text(
            text = commit.hash.take(7),
            style = MaterialTheme.typography.labelSmall.copy(fontFamily = FontFamily.Monospace),
            color = Accent,
            modifier = Modifier.width(56.dp)
        )
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = commit.message.lines().first(),
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurface,
                maxLines = 1,
                overflow = androidx.compose.ui.text.style.TextOverflow.Ellipsis
            )
            Row(horizontalArrangement = Arrangement.spacedBy(DS.Spacing.s)) {
                Text(
                    text = commit.author.substringBefore(" <"),
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = DS.Opacity.m)
                )
                if (commit.date > 0) {
                    Text(
                        text = formatCommitTime(commit.date),
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.onSurface.copy(alpha = DS.Opacity.m)
                    )
                }
            }
        }
    }
}

private fun formatCommitTime(epochSeconds: Double): String {
    val diff = (System.currentTimeMillis() / 1000.0 - epochSeconds).toLong()
    val minutes = diff / 60
    val hours = minutes / 60
    val days = hours / 24
    return when {
        minutes < 1 -> "now"
        minutes < 60 -> "${minutes}m ago"
        hours < 24 -> "${hours}h ago"
        days < 7 -> "${days}d ago"
        else -> "${days / 7}w ago"
    }
}

package com.cloude.app.UI.chat

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.Folder
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
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
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.style.TextOverflow
import com.cloude.app.Models.ClientMessage
import com.cloude.app.Models.EnvironmentStore
import com.cloude.app.Models.FileEntry
import com.cloude.app.Models.ServerMessage
import com.cloude.app.Services.ConnectionManager
import com.cloude.app.Utilities.Accent
import com.cloude.app.Utilities.DS
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.filterIsInstance

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun FolderPickerSheet(
    connectionManager: ConnectionManager,
    environmentStore: EnvironmentStore? = null,
    environmentId: String,
    initialPath: String,
    onSelect: (String) -> Unit,
    onDismiss: () -> Unit
) {
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    var currentPath by remember { mutableStateOf(initialPath) }
    var folders by remember { mutableStateOf<List<FileEntry>>(emptyList()) }
    var isLoading by remember { mutableStateOf(true) }
    var isConnecting by remember { mutableStateOf(false) }
    var connectionFailed by remember { mutableStateOf(false) }

    val conn = connectionManager.connection(environmentId)
    val isAuthenticated by conn?.isAuthenticated?.collectAsState() ?: remember { mutableStateOf(false) }

    LaunchedEffect(environmentId) {
        if (!isAuthenticated) {
            val env = environmentStore?.environments?.value?.firstOrNull { it.id == environmentId }
            if (env != null) {
                isConnecting = true
                connectionManager.connectEnvironment(env)
                var waited = 0L
                while (waited < 10_000L) {
                    delay(250)
                    waited += 250
                    if (connectionManager.connection(environmentId)?.isAuthenticated?.value == true) break
                }
                isConnecting = false
                if (connectionManager.connection(environmentId)?.isAuthenticated?.value != true) {
                    connectionFailed = true
                    return@LaunchedEffect
                }
            }
        }
        connectionManager.send(ClientMessage.ListDirectory(currentPath), environmentId)
    }

    LaunchedEffect(currentPath, isAuthenticated) {
        if (isAuthenticated && !isConnecting) {
            isLoading = true
            connectionManager.send(ClientMessage.ListDirectory(currentPath), environmentId)
        }
    }

    LaunchedEffect(Unit) {
        connectionManager.events
            .filterIsInstance<ServerMessage.DirectoryListing>()
            .collect { listing ->
                currentPath = listing.path
                folders = listing.entries
                    .filter { it.isDirectory }
                    .sortedBy { it.name.lowercase() }
                isLoading = false
            }
    }

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
        containerColor = MaterialTheme.colorScheme.surfaceVariant
    ) {
        Column(modifier = Modifier.padding(bottom = DS.Spacing.xl)) {
            Text(
                text = "Select Working Directory",
                style = MaterialTheme.typography.titleMedium,
                color = MaterialTheme.colorScheme.onSurface,
                modifier = Modifier.padding(horizontal = DS.Spacing.l, vertical = DS.Spacing.s)
            )
            Text(
                text = currentPath,
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = DS.Opacity.m),
                maxLines = 2,
                overflow = TextOverflow.Ellipsis,
                modifier = Modifier.padding(horizontal = DS.Spacing.l)
            )

            HorizontalDivider(
                color = MaterialTheme.colorScheme.outline.copy(alpha = 0.2f),
                modifier = Modifier.padding(vertical = DS.Spacing.s)
            )

            if (isConnecting || connectionFailed) {
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(DS.Size.xxl),
                    contentAlignment = Alignment.Center
                ) {
                    if (isConnecting) {
                        Column(horizontalAlignment = Alignment.CenterHorizontally) {
                            CircularProgressIndicator(color = Accent, modifier = Modifier.size(DS.Size.m))
                            Text(
                                text = "Connecting...",
                                style = MaterialTheme.typography.labelSmall,
                                color = MaterialTheme.colorScheme.onSurface.copy(alpha = DS.Opacity.m),
                                modifier = Modifier.padding(top = DS.Spacing.s)
                            )
                        }
                    } else {
                        Text(
                            text = "Connection failed",
                            style = MaterialTheme.typography.bodyMedium,
                            color = MaterialTheme.colorScheme.error
                        )
                    }
                }
            } else if (isLoading) {
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(DS.Size.xxl),
                    contentAlignment = Alignment.Center
                ) {
                    CircularProgressIndicator(color = Accent, modifier = Modifier.size(DS.Size.m))
                }
            } else {
                LazyColumn(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(DS.Size.xxl * 1.5f)
                ) {
                    if (currentPath != "/") {
                        item {
                            Row(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .clickable {
                                        currentPath = currentPath.substringBeforeLast("/").ifEmpty { "/" }
                                    }
                                    .padding(horizontal = DS.Spacing.l, vertical = DS.Spacing.m),
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Icon(Icons.Default.Folder, null, tint = Color(0xFF64B5F6), modifier = Modifier.size(DS.Icon.l))
                                Spacer(modifier = Modifier.width(DS.Spacing.m))
                                Text(
                                    text = "..",
                                    style = MaterialTheme.typography.bodyMedium,
                                    color = MaterialTheme.colorScheme.onSurface
                                )
                            }
                        }
                    }
                    items(folders, key = { it.path }) { folder ->
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .clickable { currentPath = folder.path }
                                .padding(horizontal = DS.Spacing.l, vertical = DS.Spacing.m),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Icon(Icons.Default.Folder, null, tint = Color(0xFF64B5F6), modifier = Modifier.size(DS.Icon.l))
                            Spacer(modifier = Modifier.width(DS.Spacing.m))
                            Text(
                                text = folder.name,
                                style = MaterialTheme.typography.bodyMedium,
                                color = MaterialTheme.colorScheme.onSurface,
                                modifier = Modifier.weight(1f)
                            )
                            Icon(Icons.Default.ChevronRight, null, tint = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.3f), modifier = Modifier.size(DS.Icon.m))
                        }
                    }
                }
            }

            Button(
                onClick = {
                    onSelect(currentPath)
                    onDismiss()
                },
                colors = ButtonDefaults.buttonColors(containerColor = Accent),
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = DS.Spacing.l, vertical = DS.Spacing.s)
            ) {
                Text("Select This Folder")
            }
        }
    }
}

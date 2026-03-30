package com.cloude.app.UI.deploy

import android.content.Context
import android.content.Intent
import android.util.Base64
import androidx.compose.foundation.background
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Error
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
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.unit.sp
import androidx.core.content.FileProvider
import com.cloude.app.Models.ClientMessage
import com.cloude.app.Models.ServerMessage
import com.cloude.app.Services.ConnectionManager
import com.cloude.app.Utilities.Accent
import com.cloude.app.Utilities.DS
import com.cloude.app.Utilities.PastelGreen
import com.cloude.app.Utilities.PastelRed
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.File

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun DeploySheet(
    connectionManager: ConnectionManager,
    environmentId: String,
    workingDirectory: String,
    onDismiss: () -> Unit
) {
    val context = LocalContext.current
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    val outputLines = remember { mutableStateListOf<String>() }
    var phase by remember { mutableStateOf("building") }
    val listState = rememberLazyListState()
    val deployId = remember { "deploy-${System.currentTimeMillis()}" }
    val apkPath = "$workingDirectory/android/app/build/outputs/apk/debug/app-debug.apk"

    LaunchedEffect(Unit) {
        launch {
            connectionManager.events.collect { msg ->
                when {
                    msg is ServerMessage.TerminalOutput && msg.terminalId == deployId -> {
                        msg.output.lines().filter { it.isNotBlank() }.forEach { outputLines.add(it) }
                        if (msg.exitCode != null) {
                            if (msg.exitCode == 0 && phase == "building") {
                                phase = "transferring"
                                outputLines.add("")
                                outputLines.add("Transferring APK...")
                                connectionManager.send(
                                    ClientMessage.GetFileFullQuality(apkPath),
                                    environmentId
                                )
                            } else if (msg.exitCode != 0) {
                                phase = "error"
                                outputLines.add("Build failed with exit code ${msg.exitCode}")
                            }
                        }
                    }
                    msg is ServerMessage.FileChunk && phase == "transferring" -> {
                        outputLines.removeAll { it.startsWith("Receiving chunk") }
                        outputLines.add("Receiving chunk ${msg.chunkIndex + 1}/${msg.totalChunks}")
                    }
                    msg is ServerMessage.FileContent && phase == "transferring" -> {
                        outputLines.add("APK received (${msg.size / 1024}KB)")
                        outputLines.add("Installing...")
                        phase = "installing"
                        val success = saveAndInstall(context, msg.data)
                        if (success) {
                            phase = "done"
                            outputLines.add("")
                            outputLines.add("Install dialog opened!")
                        } else {
                            phase = "error"
                            outputLines.add("Failed to save APK")
                        }
                    }
                    else -> {}
                }
            }
        }

        outputLines.add("Building APK...")
        val buildCmd = "export JAVA_HOME=\"/Applications/Android Studio.app/Contents/jbr/Contents/Home\" && " +
            "cd $workingDirectory/android && " +
            "./gradlew assembleDebug --daemon 2>&1"
        connectionManager.send(
            ClientMessage.TerminalExec(buildCmd, workingDirectory, deployId),
            environmentId
        )
    }

    LaunchedEffect(outputLines.size) {
        if (outputLines.isNotEmpty()) listState.animateScrollToItem(outputLines.size - 1)
    }

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
        containerColor = MaterialTheme.colorScheme.surfaceVariant
    ) {
        Column(modifier = Modifier.padding(bottom = DS.Spacing.xl)) {
            Row(
                modifier = Modifier.padding(horizontal = DS.Spacing.l, vertical = DS.Spacing.s),
                verticalAlignment = Alignment.CenterVertically
            ) {
                when (phase) {
                    "done" -> Icon(Icons.Default.CheckCircle, null, tint = PastelGreen, modifier = Modifier.size(DS.Icon.l))
                    "error" -> Icon(Icons.Default.Error, null, tint = PastelRed, modifier = Modifier.size(DS.Icon.l))
                    else -> CircularProgressIndicator(color = Accent, modifier = Modifier.size(DS.Icon.l), strokeWidth = DS.Stroke.m)
                }
                Text(
                    text = when (phase) {
                        "done" -> "Ready to Install"
                        "error" -> "Deploy Failed"
                        "transferring" -> "Transferring APK..."
                        "installing" -> "Installing..."
                        else -> "Building..."
                    },
                    style = MaterialTheme.typography.titleMedium,
                    color = MaterialTheme.colorScheme.onSurface,
                    modifier = Modifier.padding(start = DS.Spacing.m)
                )
            }

            HorizontalDivider(color = MaterialTheme.colorScheme.outline.copy(alpha = 0.2f))

            LazyColumn(
                state = listState,
                modifier = Modifier
                    .fillMaxWidth()
                    .height(DS.Size.xxl * 1.5f)
                    .padding(DS.Spacing.m)
                    .background(MaterialTheme.colorScheme.surface, RoundedCornerShape(DS.Radius.m))
                    .padding(DS.Spacing.s)
            ) {
                items(outputLines) { line ->
                    Text(
                        text = line,
                        style = MaterialTheme.typography.bodySmall.copy(
                            fontFamily = FontFamily.Monospace,
                            lineHeight = 16.sp
                        ),
                        color = when {
                            line.contains("SUCCESS") -> PastelGreen
                            line.contains("FAILED") || line.contains("Error") || line.contains("failed") -> PastelRed
                            line.startsWith("Installing") || line.startsWith("Building") ||
                                line.startsWith("Transferring") || line.startsWith("APK received") ||
                                line.startsWith("Install dialog") -> Accent
                            else -> MaterialTheme.colorScheme.onSurface.copy(alpha = 0.7f)
                        },
                        modifier = Modifier
                            .fillMaxWidth()
                            .horizontalScroll(rememberScrollState())
                    )
                }
            }
        }
    }
}

private suspend fun saveAndInstall(context: Context, base64Data: String): Boolean {
    val apkFile = withContext(Dispatchers.IO) {
        val bytes = try {
            Base64.decode(base64Data, Base64.DEFAULT)
        } catch (e: Exception) {
            return@withContext null
        }
        val file = File(context.cacheDir, "cloude-update.apk")
        file.writeBytes(bytes)
        file
    } ?: return false

    val uri = FileProvider.getUriForFile(context, "com.cloude.app.fileprovider", apkFile)
    val intent = Intent(Intent.ACTION_VIEW).apply {
        setDataAndType(uri, "application/vnd.android.package-archive")
        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
    }
    context.startActivity(intent)
    return true
}

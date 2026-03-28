package com.cloude.app.UI.deploy

import android.util.Log
import androidx.compose.foundation.background
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
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
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.sp
import com.cloude.app.Models.ClientMessage
import com.cloude.app.Models.ServerMessage
import com.cloude.app.Services.ConnectionManager
import com.cloude.app.Utilities.Accent
import com.cloude.app.Utilities.DS
import com.cloude.app.Utilities.PastelGreen
import com.cloude.app.Utilities.PastelRed

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun DeploySheet(
    connectionManager: ConnectionManager,
    environmentId: String,
    workingDirectory: String,
    onDismiss: () -> Unit
) {
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    val outputLines = remember { mutableStateListOf<String>() }
    var isBuilding by remember { mutableStateOf(true) }
    var isInstalling by remember { mutableStateOf(false) }
    var isDone by remember { mutableStateOf(false) }
    var isError by remember { mutableStateOf(false) }
    val listState = rememberLazyListState()

    val deployId = remember { "deploy-${System.currentTimeMillis()}" }

    LaunchedEffect(Unit) {
        outputLines.add("Building APK...")
        val buildCmd = "export JAVA_HOME=\"/Applications/Android Studio.app/Contents/jbr/Contents/Home\" && " +
            "cd $workingDirectory/android && " +
            "./gradlew assembleDebug 2>&1"
        connectionManager.send(
            ClientMessage.TerminalExec(buildCmd, workingDirectory, deployId),
            environmentId
        )
    }

    LaunchedEffect(Unit) {
        connectionManager.events.collect { msg ->
            if (msg is ServerMessage.TerminalOutput && msg.terminalId == deployId) {
                msg.output.lines().filter { it.isNotBlank() }.forEach { line ->
                    outputLines.add(line)
                }

                if (msg.exitCode != null) {
                    if (msg.exitCode == 0 && isBuilding) {
                        isBuilding = false
                        isInstalling = true
                        outputLines.add("")
                        outputLines.add("Installing on device...")
                        val installCmd = "adb install -r $workingDirectory/android/app/build/outputs/apk/debug/app-debug.apk 2>&1"
                        connectionManager.send(
                            ClientMessage.TerminalExec(installCmd, workingDirectory, deployId),
                            environmentId
                        )
                    } else if (msg.exitCode == 0 && isInstalling) {
                        isInstalling = false
                        isDone = true
                        outputLines.add("")
                        outputLines.add("Deployed successfully!")
                    } else {
                        isBuilding = false
                        isInstalling = false
                        isError = true
                        outputLines.add("")
                        outputLines.add("Failed with exit code ${msg.exitCode}")
                    }
                }
            }
        }
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
                when {
                    isDone -> Icon(Icons.Default.CheckCircle, null, tint = PastelGreen, modifier = Modifier.size(DS.Icon.l))
                    isError -> Icon(Icons.Default.Error, null, tint = PastelRed, modifier = Modifier.size(DS.Icon.l))
                    else -> CircularProgressIndicator(color = Accent, modifier = Modifier.size(DS.Icon.l), strokeWidth = DS.Stroke.m)
                }
                Text(
                    text = when {
                        isDone -> "Deployed"
                        isError -> "Deploy Failed"
                        isInstalling -> "Installing..."
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
                            line.contains("FAILED") || line.contains("Error") -> PastelRed
                            line.startsWith("Installing") || line.startsWith("Building") || line.startsWith("Deployed") -> Accent
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

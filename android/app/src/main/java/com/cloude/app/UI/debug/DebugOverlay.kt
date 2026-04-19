package com.cloude.app.UI.debug

import android.content.SharedPreferences
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.BugReport
import androidx.compose.material.icons.filled.Close
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.layout.positionInParent
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import kotlin.math.roundToInt
import com.cloude.app.Services.ConnectionManager
import com.cloude.app.Utilities.Accent
import com.cloude.app.Utilities.DS
import com.cloude.app.Utilities.PastelGreen
import com.cloude.app.Utilities.PastelRed
import kotlinx.coroutines.delay

@Composable
fun DebugOverlay(
    connectionManager: ConnectionManager,
    environmentId: String,
    modifier: Modifier = Modifier
) {
    val prefs = LocalContext.current.getSharedPreferences("cloude", android.content.Context.MODE_PRIVATE)
    val density = LocalDensity.current
    var expanded by remember { mutableStateOf(false) }
    var offsetX by remember { mutableFloatStateOf(prefs.getFloat("debugX", -1f)) }
    var offsetY by remember { mutableFloatStateOf(prefs.getFloat("debugY", -1f)) }
    val isConnected by connectionManager.isConnected.collectAsState()
    val isAuthenticated by connectionManager.isAuthenticated.collectAsState()
    val agentState by connectionManager.agentState.collectAsState()
    val conn = connectionManager.connection(environmentId)
    val lastError by conn?.lastError?.collectAsState() ?: remember { mutableStateOf(null) }
    var uptime by remember { mutableLongStateOf(0L) }
    var parentWidth by remember { mutableFloatStateOf(0f) }
    var parentHeight by remember { mutableFloatStateOf(0f) }
    var pillWidth by remember { mutableFloatStateOf(0f) }
    var pillHeight by remember { mutableFloatStateOf(0f) }

    LaunchedEffect(Unit) {
        while (true) {
            delay(1000)
            uptime++
        }
    }

    Box(
        modifier = modifier
            .onGloballyPositioned { coords ->
                parentWidth = coords.size.width.toFloat()
                parentHeight = coords.size.height.toFloat()
                val needsReset = offsetX < 0f || offsetY < 0f
                    || offsetX > parentWidth || offsetY > parentHeight
                if (needsReset) {
                    offsetX = with(density) { DS.Spacing.m.toPx() }
                    offsetY = (parentHeight - with(density) { 120.dp.toPx() }).coerceAtLeast(0f)
                    prefs.edit().putFloat("debugX", offsetX).putFloat("debugY", offsetY).apply()
                }
            }
            .offset { IntOffset(offsetX.roundToInt(), offsetY.roundToInt()) }
            .pointerInput(expanded) {
                if (!expanded) {
                    detectDragGestures(
                        onDragEnd = {
                            prefs.edit().putFloat("debugX", offsetX).putFloat("debugY", offsetY).apply()
                        }
                    ) { change, dragAmount ->
                        change.consume()
                        val maxX = (parentWidth - pillWidth).coerceAtLeast(0f)
                        val maxY = (parentHeight - pillHeight).coerceAtLeast(0f)
                        offsetX = (offsetX + dragAmount.x).coerceIn(0f, maxX)
                        offsetY = (offsetY + dragAmount.y).coerceIn(0f, maxY)
                    }
                }
            }
            .padding(DS.Spacing.m)
    ) {
        if (!expanded) {
            Row(
                modifier = Modifier
                    .onGloballyPositioned { coords ->
                        pillWidth = coords.size.width.toFloat()
                        pillHeight = coords.size.height.toFloat()
                    }
                    .clip(RoundedCornerShape(DS.Radius.m))
                    .background(MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.95f))
                    .clickable {
                        expanded = true
                        offsetX = with(density) { DS.Spacing.m.toPx() }
                        offsetY = with(density) { DS.Spacing.m.toPx() }
                    }
                    .padding(horizontal = DS.Spacing.m, vertical = DS.Spacing.xs),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(DS.Spacing.xs)
            ) {
                Box(
                    modifier = Modifier
                        .size(DS.Spacing.s)
                        .clip(CircleShape)
                        .background(if (isAuthenticated) PastelGreen else PastelRed)
                )
                Icon(
                    Icons.Default.BugReport,
                    contentDescription = null,
                    tint = Accent,
                    modifier = Modifier.size(DS.Icon.s)
                )
                Text(
                    text = agentState.name,
                    style = MaterialTheme.typography.labelSmall.copy(fontFamily = FontFamily.Monospace),
                    color = MaterialTheme.colorScheme.onSurface
                )
            }
        } else {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(DS.Radius.m))
                    .background(MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.97f))
                    .padding(DS.Spacing.m)
            ) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        text = "Debug",
                        style = MaterialTheme.typography.titleSmall,
                        color = MaterialTheme.colorScheme.onSurface
                    )
                    IconButton(
                        onClick = {
                            expanded = false
                            val savedX = prefs.getFloat("debugX", -1f)
                            val savedY = prefs.getFloat("debugY", -1f)
                            offsetX = if (savedX >= 0f) savedX else with(density) { DS.Spacing.m.toPx() }
                            offsetY = if (savedY >= 0f) savedY else parentHeight - with(density) { 120.dp.toPx() }
                        },
                        modifier = Modifier.size(DS.Size.m)
                    ) {
                        Icon(Icons.Default.Close, null, tint = MaterialTheme.colorScheme.onSurface, modifier = Modifier.size(DS.Icon.s))
                    }
                }

                HorizontalDivider(
                    color = MaterialTheme.colorScheme.outline.copy(alpha = 0.2f),
                    modifier = Modifier.padding(vertical = DS.Spacing.xs)
                )

                MetricRow("Connection", if (isAuthenticated) "authenticated" else if (isConnected) "connected" else "disconnected",
                    color = if (isAuthenticated) PastelGreen else if (isConnected) Accent else PastelRed)
                MetricRow("Agent", agentState.name)
                MetricRow("Uptime", formatUptime(uptime))
                lastError?.let { MetricRow("Last Error", it, color = PastelRed) }
            }
        }
    }
}

@Composable
private fun MetricRow(label: String, value: String, color: androidx.compose.ui.graphics.Color? = null) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 2.dp),
        horizontalArrangement = Arrangement.SpaceBetween
    ) {
        Text(
            text = label,
            style = MaterialTheme.typography.labelSmall.copy(fontFamily = FontFamily.Monospace),
            color = MaterialTheme.colorScheme.onSurface.copy(alpha = DS.Opacity.l)
        )
        Text(
            text = value,
            style = MaterialTheme.typography.labelSmall.copy(fontFamily = FontFamily.Monospace),
            color = color ?: MaterialTheme.colorScheme.onSurface
        )
    }
}

private fun formatUptime(seconds: Long): String {
    val h = seconds / 3600
    val m = (seconds % 3600) / 60
    val s = seconds % 60
    return if (h > 0) "${h}h ${m}m ${s}s" else if (m > 0) "${m}m ${s}s" else "${s}s"
}

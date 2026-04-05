package com.cloude.app.UI.whiteboard

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.gestures.detectTransformGestures
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
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Circle
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Create
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.PanTool
import androidx.compose.material.icons.filled.Rectangle
import androidx.compose.material.icons.filled.TextFields
import androidx.compose.material.icons.filled.TrendingFlat
import androidx.compose.material.icons.filled.Undo
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
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
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.unit.dp
import com.cloude.app.Utilities.Accent
import com.cloude.app.Utilities.DS
import java.util.UUID

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun WhiteboardSheet(
    state: WhiteboardCanvasState,
    onStateChange: (WhiteboardCanvasState) -> Unit,
    onDismiss: () -> Unit
) {
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    var drawingPoints by remember { mutableStateOf<List<List<Double>>>(emptyList()) }
    var arrowSource by remember { mutableStateOf<String?>(null) }

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
        containerColor = MaterialTheme.colorScheme.background
    ) {
        Column(modifier = Modifier.fillMaxWidth()) {
            Toolbar(
                activeTool = state.activeTool,
                activeColor = state.activeColor,
                hasSelection = state.selectedIds.isNotEmpty(),
                onToolChange = { onStateChange(state.copy(activeTool = it, selectedIds = emptySet())) },
                onColorChange = { onStateChange(state.copy(activeColor = it)) },
                onDelete = {
                    val remaining = state.elements.filter { it.id !in state.selectedIds }
                    onStateChange(state.copy(elements = remaining, selectedIds = emptySet()))
                },
                onClear = { onStateChange(state.copy(elements = emptyList(), selectedIds = emptySet())) }
            )

            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(400.dp)
                    .background(MaterialTheme.colorScheme.surface)
                    .pointerInput(Unit) {
                        detectTransformGestures { _, pan, zoom, _ ->
                            val vp = state.viewport
                            val newZoom = (vp.zoom * zoom).coerceIn(0.3, 5.0)
                            onStateChange(
                                state.copy(
                                    viewport = vp.copy(
                                        x = vp.x - pan.x / newZoom,
                                        y = vp.y - pan.y / newZoom,
                                        zoom = newZoom
                                    )
                                )
                            )
                        }
                    }
                    .then(
                        if (state.activeTool == ActiveTool.Hand) Modifier
                        else Modifier.pointerInput(state.activeTool) {
                            when (state.activeTool) {
                                ActiveTool.Hand -> {}
                                ActiveTool.Pencil -> detectDragGestures(
                                onDragStart = { offset ->
                                    drawingPoints = listOf(screenToCanvas(offset, size, state.viewport))
                                },
                                onDrag = { _, dragAmount ->
                                    val last = drawingPoints.lastOrNull() ?: return@detectDragGestures
                                    val vp = state.viewport
                                    val dx = dragAmount.x / vp.zoom
                                    val dy = dragAmount.y / vp.zoom
                                    drawingPoints = drawingPoints + listOf(listOf(last[0] + dx, last[1] + dy))
                                },
                                onDragEnd = {
                                    if (drawingPoints.size >= 2) {
                                        val el = WhiteboardElement(
                                            id = UUID.randomUUID().toString().take(8),
                                            type = "path",
                                            points = drawingPoints,
                                            stroke = state.activeColor,
                                            strokeWidth = 2.0
                                        )
                                        onStateChange(state.copy(elements = state.elements + el))
                                    }
                                    drawingPoints = emptyList()
                                }
                            )
                            ActiveTool.Arrow -> detectTapGestures { offset ->
                                val canvas = screenToCanvas(offset, size, state.viewport)
                                val hit = hitTest(state.elements, canvas[0], canvas[1])
                                if (arrowSource == null) {
                                    arrowSource = hit?.id
                                } else if (hit != null && hit.id != arrowSource) {
                                    val el = WhiteboardElement(
                                        id = UUID.randomUUID().toString().take(8),
                                        type = "arrow",
                                        from = arrowSource,
                                        to = hit.id,
                                        stroke = state.activeColor
                                    )
                                    onStateChange(state.copy(elements = state.elements + el))
                                    arrowSource = null
                                } else {
                                    arrowSource = null
                                }
                            }
                            else -> detectTapGestures { offset ->
                                val canvas = screenToCanvas(offset, size, state.viewport)
                                val hit = hitTest(state.elements, canvas[0], canvas[1])
                                if (hit != null) {
                                    onStateChange(state.copy(selectedIds = setOf(hit.id)))
                                } else {
                                    val el = WhiteboardElement(
                                        id = UUID.randomUUID().toString().take(8),
                                        type = when (state.activeTool) {
                                            ActiveTool.Rect -> "rect"
                                            ActiveTool.Ellipse -> "ellipse"
                                            ActiveTool.Triangle -> "triangle"
                                            ActiveTool.Text -> "text"
                                            else -> "rect"
                                        },
                                        x = canvas[0] - 50,
                                        y = canvas[1] - 30,
                                        w = 100.0,
                                        h = 60.0,
                                        fill = state.activeColor,
                                        stroke = "#FFFFFF",
                                        label = if (state.activeTool == ActiveTool.Text) "Text" else null,
                                        fontSize = 14.0
                                    )
                                    onStateChange(state.copy(elements = state.elements + el))
                                }
                            }
                        }
                    })
            ) {
                WhiteboardCanvas(
                    state = if (drawingPoints.size >= 2) {
                        val liveEl = WhiteboardElement(
                            id = "drawing",
                            type = "path",
                            points = drawingPoints,
                            stroke = state.activeColor,
                            strokeWidth = 2.0
                        )
                        state.copy(elements = state.elements + liveEl)
                    } else state
                )
            }

            Spacer(modifier = Modifier.height(DS.Spacing.l))
        }
    }
}

@Composable
private fun Toolbar(
    activeTool: ActiveTool,
    activeColor: String,
    hasSelection: Boolean,
    onToolChange: (ActiveTool) -> Unit,
    onColorChange: (String) -> Unit,
    onDelete: () -> Unit,
    onClear: () -> Unit
) {
    Column(modifier = Modifier.padding(horizontal = DS.Spacing.m, vertical = DS.Spacing.xs)) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceEvenly,
            verticalAlignment = Alignment.CenterVertically
        ) {
            ToolButton(Icons.Default.PanTool, "Hand", activeTool == ActiveTool.Hand) { onToolChange(ActiveTool.Hand) }
            ToolButton(Icons.Default.Rectangle, "Rect", activeTool == ActiveTool.Rect) { onToolChange(ActiveTool.Rect) }
            ToolButton(Icons.Default.Circle, "Ellipse", activeTool == ActiveTool.Ellipse) { onToolChange(ActiveTool.Ellipse) }
            ToolButton(Icons.Default.TextFields, "Text", activeTool == ActiveTool.Text) { onToolChange(ActiveTool.Text) }
            ToolButton(Icons.Default.Create, "Draw", activeTool == ActiveTool.Pencil) { onToolChange(ActiveTool.Pencil) }
            ToolButton(Icons.Default.TrendingFlat, "Arrow", activeTool == ActiveTool.Arrow) { onToolChange(ActiveTool.Arrow) }
            if (hasSelection) {
                IconButton(onClick = onDelete, modifier = Modifier.size(DS.Size.m)) {
                    Icon(Icons.Default.Delete, null, tint = com.cloude.app.Utilities.PastelRed, modifier = Modifier.size(DS.Icon.m))
                }
            }
        }

        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(top = DS.Spacing.xs),
            horizontalArrangement = Arrangement.Center,
            verticalAlignment = Alignment.CenterVertically
        ) {
            paletteColors.forEach { hex ->
                val color = parseHexColor(hex)
                Box(
                    modifier = Modifier
                        .size(24.dp)
                        .padding(2.dp)
                        .clip(CircleShape)
                        .background(color)
                        .then(
                            if (hex == activeColor) Modifier.border(2.dp, Accent, CircleShape)
                            else Modifier
                        )
                        .clickable { onColorChange(hex) }
                )
            }
            Spacer(modifier = Modifier.weight(1f))
            Text(
                text = "Clear",
                style = MaterialTheme.typography.labelSmall,
                color = com.cloude.app.Utilities.PastelRed,
                modifier = Modifier
                    .clip(RoundedCornerShape(DS.Radius.s))
                    .clickable { onClear() }
                    .padding(horizontal = DS.Spacing.s, vertical = DS.Spacing.xs)
            )
        }
    }
}

@Composable
private fun ToolButton(icon: ImageVector, label: String, active: Boolean, onClick: () -> Unit) {
    IconButton(onClick = onClick, modifier = Modifier.size(DS.Size.m)) {
        Icon(
            icon, label,
            tint = if (active) Accent else MaterialTheme.colorScheme.onSurface.copy(alpha = DS.Opacity.l),
            modifier = Modifier.size(DS.Icon.m)
        )
    }
}

private fun screenToCanvas(offset: Offset, size: androidx.compose.ui.unit.IntSize, vp: WhiteboardViewport): List<Double> {
    val cx = size.width / 2.0
    val cy = size.height / 2.0
    val x = (offset.x - cx) / vp.zoom + 500 + vp.x
    val y = (offset.y - cy) / vp.zoom + 500 + vp.y
    return listOf(x, y)
}

private fun hitTest(elements: List<WhiteboardElement>, x: Double, y: Double): WhiteboardElement? =
    elements.lastOrNull { el ->
        el.type != "arrow" && el.type != "path" &&
            x >= el.x && x <= el.x + el.w && y >= el.y && y <= el.y + el.h
    }

private fun parseHexColor(hex: String): androidx.compose.ui.graphics.Color {
    val clean = hex.removePrefix("#")
    val r = clean.substring(0, 2).toInt(16)
    val g = clean.substring(2, 4).toInt(16)
    val b = clean.substring(4, 6).toInt(16)
    return androidx.compose.ui.graphics.Color(r, g, b)
}

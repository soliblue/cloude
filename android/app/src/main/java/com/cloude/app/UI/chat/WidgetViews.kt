package com.cloude.app.UI.chat

import androidx.compose.animation.animateContentSize
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.Description
import androidx.compose.material.icons.filled.ExpandMore
import androidx.compose.material.icons.filled.Folder
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.cloude.app.Utilities.Accent
import com.cloude.app.Utilities.DS
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.doubleOrNull
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive

private val json = Json { ignoreUnknownKeys = true; isLenient = true }

private val CHART_COLORS = listOf(
    Color(0xFFE57373), Color(0xFF81C784), Color(0xFF64B5F6),
    Color(0xFFFFD54F), Color(0xFFBA68C8), Color(0xFF4DB6AC),
    Color(0xFFFF8A65), Color(0xFFA1887F), Color(0xFF90A4AE),
    Color(0xFFF06292)
)

fun isWidget(toolName: String): Boolean = toolName.startsWith("mcp__widgets__")

@Composable
fun WidgetView(toolName: String, inputJson: String?) {
    val data = remember(inputJson) {
        inputJson?.let {
            try { json.parseToJsonElement(it).jsonObject } catch (_: Exception) { null }
        }
    } ?: return

    WidgetContainer {
        when (toolName.removePrefix("mcp__widgets__")) {
            "pie_chart" -> PieChartWidget(data)
            "timeline" -> TimelineWidget(data)
            "tree" -> TreeWidget(data)
            "color_palette" -> ColorPaletteWidget(data)
            else -> Text(
                text = "Unknown widget: $toolName",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = DS.Opacity.m)
            )
        }
    }
}

@Composable
private fun WidgetContainer(content: @Composable () -> Unit) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(DS.Radius.m))
            .background(MaterialTheme.colorScheme.surface.copy(alpha = 0.6f))
            .padding(DS.Spacing.l),
        verticalArrangement = Arrangement.spacedBy(DS.Spacing.m)
    ) {
        content()
    }
}

@Composable
private fun WidgetTitle(title: String?) {
    if (title?.isNotBlank() == true) {
        Text(
            text = title,
            style = MaterialTheme.typography.titleSmall,
            fontWeight = FontWeight.SemiBold,
            color = MaterialTheme.colorScheme.onSurface
        )
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun PieChartWidget(data: JsonObject) {
    val title = data["title"]?.jsonPrimitive?.contentOrNull
    val slices = data["slices"]?.jsonArray?.mapNotNull { el ->
        val obj = el.jsonObject
        val label = obj["label"]?.jsonPrimitive?.contentOrNull ?: return@mapNotNull null
        val value = obj["value"]?.jsonPrimitive?.doubleOrNull ?: return@mapNotNull null
        label to value
    } ?: return

    val total = slices.sumOf { it.second }
    if (total <= 0) return
    var selectedIndex by remember { mutableIntStateOf(-1) }

    WidgetTitle(title)

    Canvas(
        modifier = Modifier
            .fillMaxWidth()
            .height(200.dp)
    ) {
        val diameter = minOf(size.width, size.height) * 0.8f
        val innerRadius = diameter * 0.25f
        val topLeft = Offset((size.width - diameter) / 2, (size.height - diameter) / 2)

        var startAngle = -90f
        slices.forEachIndexed { index, (_, value) ->
            val sweep = (value / total * 360).toFloat()
            val alpha = if (selectedIndex >= 0 && selectedIndex != index) 0.3f else 1f
            val color = CHART_COLORS[index % CHART_COLORS.size].copy(alpha = alpha)
            drawArc(
                color = color,
                startAngle = startAngle,
                sweepAngle = sweep,
                useCenter = true,
                topLeft = topLeft,
                size = Size(diameter, diameter)
            )
            startAngle += sweep
        }

        drawCircle(
            color = Color(0xFF1E1E2E),
            radius = innerRadius,
            center = Offset(size.width / 2, size.height / 2)
        )
    }

    FlowRow(
        horizontalArrangement = Arrangement.spacedBy(DS.Spacing.m),
        verticalArrangement = Arrangement.spacedBy(DS.Spacing.xs)
    ) {
        slices.forEachIndexed { index, (label, value) ->
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(DS.Spacing.xs),
                modifier = Modifier.clickable {
                    selectedIndex = if (selectedIndex == index) -1 else index
                }
            ) {
                Box(
                    modifier = Modifier
                        .size(10.dp)
                        .clip(CircleShape)
                        .background(CHART_COLORS[index % CHART_COLORS.size])
                )
                Text(
                    text = "$label ${String.format("%.0f", value / total * 100)}%",
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurface.copy(
                        alpha = if (selectedIndex >= 0 && selectedIndex != index) 0.4f else 1f
                    )
                )
            }
        }
    }
}

@Composable
private fun TimelineWidget(data: JsonObject) {
    val title = data["title"]?.jsonPrimitive?.contentOrNull
    val events = data["events"]?.jsonArray?.mapNotNull { el ->
        val obj = el.jsonObject
        val eventTitle = obj["title"]?.jsonPrimitive?.contentOrNull ?: return@mapNotNull null
        val date = obj["date"]?.jsonPrimitive?.contentOrNull
        val description = obj["description"]?.jsonPrimitive?.contentOrNull
        val colorName = obj["color"]?.jsonPrimitive?.contentOrNull
        TimelineEvent(date, eventTitle, description, colorFromName(colorName) ?: Accent)
    } ?: return

    WidgetTitle(title)

    Column {
        events.forEachIndexed { index, event ->
            Row(modifier = Modifier.fillMaxWidth()) {
                Column(
                    horizontalAlignment = Alignment.CenterHorizontally,
                    modifier = Modifier.width(24.dp)
                ) {
                    Box(
                        modifier = Modifier
                            .size(12.dp)
                            .clip(CircleShape)
                            .background(event.color)
                    )
                    if (index < events.lastIndex) {
                        Box(
                            modifier = Modifier
                                .width(2.dp)
                                .height(40.dp)
                                .background(event.color.copy(alpha = 0.3f))
                        )
                    }
                }
                Column(
                    modifier = Modifier
                        .weight(1f)
                        .padding(start = DS.Spacing.m, bottom = DS.Spacing.m)
                ) {
                    if (event.date != null) {
                        Text(
                            text = event.date,
                            style = MaterialTheme.typography.labelSmall,
                            color = MaterialTheme.colorScheme.onSurface.copy(alpha = DS.Opacity.m)
                        )
                    }
                    Text(
                        text = event.title,
                        style = MaterialTheme.typography.bodyMedium,
                        fontWeight = FontWeight.SemiBold,
                        color = MaterialTheme.colorScheme.onSurface
                    )
                    if (event.description != null) {
                        Text(
                            text = event.description,
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurface.copy(alpha = DS.Opacity.m)
                        )
                    }
                }
            }
        }
    }
}

private data class TimelineEvent(
    val date: String?,
    val title: String,
    val description: String?,
    val color: Color
)

@Composable
private fun TreeWidget(data: JsonObject) {
    val root = data["root"]?.jsonObject ?: return
    var collapsed by remember { mutableStateOf(emptySet<String>()) }

    TreeNode(
        node = root,
        path = "root",
        depth = 0,
        collapsed = collapsed,
        onToggle = { path ->
            collapsed = if (path in collapsed) collapsed - path else collapsed + path
        }
    )
}

@Composable
private fun TreeNode(
    node: JsonObject,
    path: String,
    depth: Int,
    collapsed: Set<String>,
    onToggle: (String) -> Unit
) {
    val label = node["label"]?.jsonPrimitive?.contentOrNull ?: return
    val children = node["children"]?.jsonArray
    val hasChildren = children != null && children.isNotEmpty()
    val isCollapsed = path in collapsed
    val colorName = node["color"]?.jsonPrimitive?.contentOrNull
    val defaultColor = if (hasChildren) Color(0xFFFFD54F) else Color(0xFF64B5F6)
    val iconColor = colorFromName(colorName) ?: defaultColor

    Column(modifier = Modifier.padding(start = (depth * 20).dp)) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .then(if (hasChildren) Modifier.clickable { onToggle(path) } else Modifier)
                .padding(vertical = 2.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(DS.Spacing.xs)
        ) {
            if (hasChildren) {
                Icon(
                    imageVector = if (isCollapsed) Icons.Default.ChevronRight else Icons.Default.ExpandMore,
                    contentDescription = null,
                    modifier = Modifier.size(DS.Icon.s),
                    tint = MaterialTheme.colorScheme.onSurface.copy(alpha = DS.Opacity.m)
                )
            } else {
                Spacer(modifier = Modifier.width(DS.Icon.s))
            }
            Icon(
                imageVector = if (hasChildren) Icons.Default.Folder else Icons.Default.Description,
                contentDescription = null,
                modifier = Modifier.size(DS.Icon.s),
                tint = iconColor
            )
            Text(
                text = label,
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurface,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
        }

        if (hasChildren && !isCollapsed) {
            Column(modifier = Modifier.animateContentSize()) {
                children?.forEachIndexed { index, child ->
                    TreeNode(
                        node = child.jsonObject,
                        path = "$path/$index",
                        depth = depth + 1,
                        collapsed = collapsed,
                        onToggle = onToggle
                    )
                }
            }
        }
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun ColorPaletteWidget(data: JsonObject) {
    val title = data["title"]?.jsonPrimitive?.contentOrNull
    val colors = data["colors"]?.jsonArray?.mapNotNull { el ->
        val obj = el.jsonObject
        val hex = obj["hex"]?.jsonPrimitive?.contentOrNull ?: return@mapNotNull null
        val label = obj["label"]?.jsonPrimitive?.contentOrNull
        hex to label
    } ?: return

    WidgetTitle(title)

    FlowRow(
        horizontalArrangement = Arrangement.spacedBy(DS.Spacing.s),
        verticalArrangement = Arrangement.spacedBy(DS.Spacing.s)
    ) {
        colors.forEach { (hex, label) ->
            val color = parseHexColor(hex)
            Row(
                modifier = Modifier
                    .clip(RoundedCornerShape(DS.Radius.s))
                    .background(MaterialTheme.colorScheme.surfaceVariant)
                    .padding(DS.Spacing.s),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(DS.Spacing.s)
            ) {
                Box(
                    modifier = Modifier
                        .size(24.dp)
                        .clip(RoundedCornerShape(4.dp))
                        .background(color)
                )
                Column {
                    if (label != null) {
                        Text(
                            text = label,
                            style = MaterialTheme.typography.labelSmall,
                            fontWeight = FontWeight.Medium,
                            color = MaterialTheme.colorScheme.onSurface
                        )
                    }
                    Text(
                        text = hex.uppercase().let { if (it.startsWith("#")) it else "#$it" },
                        style = MaterialTheme.typography.labelSmall.copy(fontFamily = FontFamily.Monospace),
                        color = MaterialTheme.colorScheme.onSurface.copy(alpha = DS.Opacity.m)
                    )
                }
            }
        }
    }
}

private fun parseHexColor(hex: String): Color {
    val cleaned = hex.removePrefix("#")
    val long = cleaned.toLongOrNull(16) ?: return Color.Gray
    return when (cleaned.length) {
        6 -> Color(0xFF000000 or long)
        8 -> Color(long)
        else -> Color.Gray
    }
}

private fun colorFromName(name: String?): Color? = when (name?.lowercase()) {
    "blue" -> Color(0xFF64B5F6)
    "green" -> Color(0xFF81C784)
    "red" -> Color(0xFFE57373)
    "purple" -> Color(0xFFBA68C8)
    "orange" -> Color(0xFFFF8A65)
    "cyan" -> Color(0xFF4DD0E1)
    "pink", "magenta" -> Color(0xFFF06292)
    "yellow" -> Color(0xFFFFD54F)
    "teal" -> Color(0xFF4DB6AC)
    "indigo" -> Color(0xFF7986CB)
    "mint" -> Color(0xFF80CBC4)
    else -> null
}

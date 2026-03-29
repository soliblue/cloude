package com.cloude.app.UI.chat

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectDragGestures
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
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
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
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.cloude.app.Models.DailyActivity
import com.cloude.app.Models.UsageStats
import com.cloude.app.Utilities.Accent
import com.cloude.app.Utilities.DS

private val ChartBlue = Color(0xFF5B8DEF)
private val ChartPurple = Color(0xFFAB7AE0)
private val ChartOrange = Accent

private data class TimeRange(val label: String, val days: Int?)

private val timeRanges = listOf(
    TimeRange("7d", 7),
    TimeRange("14d", 14),
    TimeRange("30d", 30),
    TimeRange("All", null)
)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun UsageStatsSheet(
    stats: UsageStats,
    onDismiss: () -> Unit
) {
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
        containerColor = MaterialTheme.colorScheme.background,
        dragHandle = null
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = DS.Spacing.l)
                .padding(top = DS.Spacing.m, bottom = DS.Spacing.xxl)
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.End
            ) {
                IconButton(onClick = onDismiss) {
                    Icon(
                        Icons.Default.Close,
                        contentDescription = "Close",
                        tint = MaterialTheme.colorScheme.onSurface.copy(alpha = DS.Opacity.m),
                        modifier = Modifier.size(DS.Icon.m)
                    )
                }
            }

            HeroRow(stats)
            Spacer(modifier = Modifier.height(DS.Spacing.l))
            ActivityChart(stats)
            Spacer(modifier = Modifier.height(DS.Spacing.l))
            ModelsSection(stats)
            Spacer(modifier = Modifier.height(DS.Spacing.l))
            PeakHoursSection(stats)
            Spacer(modifier = Modifier.height(DS.Spacing.m))
            FooterRow(stats)
        }
    }
}

@Composable
private fun HeroRow(stats: UsageStats) {
    val totalToolCalls = stats.dailyActivity.sumOf { it.toolCallCount }
    val daysActive = stats.dailyActivity.size

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(DS.Radius.m))
            .background(Color.White.copy(alpha = DS.Opacity.s))
            .border(DS.Stroke.s, Color.White.copy(alpha = DS.Opacity.s), RoundedCornerShape(DS.Radius.m))
            .padding(vertical = DS.Spacing.m, horizontal = DS.Spacing.l),
        horizontalArrangement = Arrangement.SpaceEvenly
    ) {
        StatPill(formatNumber(stats.totalMessages), "msgs", ChartBlue)
        StatPill(formatNumber(stats.totalSessions), "sessions", ChartPurple)
        StatPill(formatNumber(totalToolCalls), "tools", ChartOrange)
        StatPill("$daysActive", "days", Color(0xFF4CAF50))
    }
}

@Composable
private fun StatPill(value: String, label: String, color: Color) {
    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        Text(
            text = value,
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.Bold,
            color = color
        )
        Text(
            text = label,
            style = MaterialTheme.typography.labelSmall,
            color = MaterialTheme.colorScheme.onSurface.copy(alpha = DS.Opacity.m)
        )
    }
}

@Composable
private fun ActivityChart(stats: UsageStats) {
    var chartMode by remember { mutableIntStateOf(0) }
    var selectedRange by remember { mutableStateOf(timeRanges[0]) }

    val activity = if (selectedRange.days != null) {
        stats.dailyActivity.takeLast(selectedRange.days!!)
    } else {
        stats.dailyActivity
    }

    val modes = listOf(
        Triple("Messages", ChartBlue) { a: DailyActivity -> a.messageCount },
        Triple("Sessions", ChartPurple) { a: DailyActivity -> a.sessionCount },
        Triple("Tool Calls", ChartOrange) { a: DailyActivity -> a.toolCallCount }
    )

    val (title, lineColor, valueExtractor) = modes[chartMode]

    CardContainer {
        Column(modifier = Modifier.padding(DS.Spacing.l)) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Row(horizontalArrangement = Arrangement.spacedBy(DS.Spacing.s)) {
                    modes.forEachIndexed { i, (_, color, _) ->
                        val isActive = chartMode == i
                        Box(
                            modifier = Modifier
                                .size(DS.Size.m)
                                .clip(RoundedCornerShape(DS.Radius.s))
                                .then(
                                    if (isActive) Modifier.background(color.copy(alpha = DS.Opacity.s))
                                    else Modifier
                                )
                                .clickable { chartMode = i },
                            contentAlignment = Alignment.Center
                        ) {
                            Box(
                                modifier = Modifier
                                    .size(8.dp)
                                    .clip(RoundedCornerShape(2.dp))
                                    .background(if (isActive) color else MaterialTheme.colorScheme.onSurface.copy(alpha = DS.Opacity.m))
                            )
                        }
                    }
                }

                Row(horizontalArrangement = Arrangement.spacedBy(DS.Spacing.xs)) {
                    timeRanges.forEach { range ->
                        val isSelected = selectedRange.label == range.label
                        Text(
                            text = range.label,
                            style = MaterialTheme.typography.labelSmall,
                            fontWeight = if (isSelected) FontWeight.SemiBold else FontWeight.Normal,
                            color = if (isSelected) Color.White else MaterialTheme.colorScheme.onSurface.copy(alpha = DS.Opacity.m),
                            modifier = Modifier
                                .clip(RoundedCornerShape(DS.Radius.s))
                                .then(
                                    if (isSelected) Modifier.background(Accent.copy(alpha = DS.Opacity.m))
                                    else Modifier
                                )
                                .clickable { selectedRange = range }
                                .padding(horizontal = DS.Spacing.s, vertical = DS.Spacing.xs)
                        )
                    }
                }
            }

            Spacer(modifier = Modifier.height(DS.Spacing.s))

            Text(
                text = title,
                style = MaterialTheme.typography.labelMedium,
                fontWeight = FontWeight.SemiBold,
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = DS.Opacity.m)
            )

            Spacer(modifier = Modifier.height(DS.Spacing.s))

            LineChart(
                data = activity,
                valueExtractor = valueExtractor,
                lineColor = lineColor,
                modifier = Modifier
                    .fillMaxWidth()
                    .height(140.dp)
            )

            if (activity.isNotEmpty()) {
                Spacer(modifier = Modifier.height(DS.Spacing.xs))
                Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                    Text(
                        text = chartDateLabel(activity.first().date),
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.3f)
                    )
                    Text(
                        text = chartDateLabel(activity.last().date),
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.3f)
                    )
                }
            }
        }
    }
}

@Composable
private fun LineChart(
    data: List<DailyActivity>,
    valueExtractor: (DailyActivity) -> Int,
    lineColor: Color,
    modifier: Modifier = Modifier
) {
    if (data.isEmpty()) return

    var selectedIndex by remember { mutableStateOf<Int?>(null) }
    val values = data.map { valueExtractor(it) }
    val maxVal = values.max().coerceAtLeast(1)

    Box(modifier = modifier) {
        if (selectedIndex != null && selectedIndex!! in data.indices) {
            val point = data[selectedIndex!!]
            Text(
                text = "${chartDateLabel(point.date)} — ${formatNumber(valueExtractor(point))}",
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = DS.Opacity.l),
                modifier = Modifier.align(Alignment.TopEnd)
            )
        }

        Canvas(
            modifier = Modifier
                .matchParentSize()
                .pointerInput(data) {
                    detectDragGestures(
                        onDragEnd = { selectedIndex = null },
                        onDragCancel = { selectedIndex = null },
                        onDrag = { change, _ ->
                            change.consume()
                            val idx = ((change.position.x / size.width) * data.size).toInt().coerceIn(0, data.size - 1)
                            selectedIndex = idx
                        },
                        onDragStart = { offset ->
                            val idx = ((offset.x / size.width) * data.size).toInt().coerceIn(0, data.size - 1)
                            selectedIndex = idx
                        }
                    )
                }
        ) {
            val w = size.width
            val h = size.height
            val stepX = if (values.size > 1) w / (values.size - 1) else w

            val points = values.mapIndexed { i, v ->
                Offset(
                    x = if (values.size > 1) i * stepX else w / 2,
                    y = h - (v.toFloat() / maxVal) * h * 0.85f
                )
            }

            val path = Path()
            points.forEachIndexed { i, pt ->
                if (i == 0) {
                    path.moveTo(pt.x, pt.y)
                } else {
                    val prev = points[i - 1]
                    val cpX = (prev.x + pt.x) / 2
                    path.cubicTo(cpX, prev.y, cpX, pt.y, pt.x, pt.y)
                }
            }

            drawPath(
                path = path,
                color = lineColor.copy(alpha = DS.Opacity.l),
                style = Stroke(width = 2.dp.toPx(), cap = StrokeCap.Round, join = StrokeJoin.Round)
            )

            points.forEachIndexed { i, pt ->
                val isSelected = selectedIndex == i
                drawCircle(
                    color = if (isSelected) Accent else lineColor,
                    radius = if (isSelected) 5.dp.toPx() else 2.5.dp.toPx(),
                    center = pt
                )
            }
        }
    }
}

@Composable
private fun ModelsSection(stats: UsageStats) {
    val sorted = stats.modelUsage.entries
        .sortedByDescending { it.value.outputTokens }
        .map { (name, tokens) -> modelDisplayName(name) to tokens }
    val maxTokens = sorted.firstOrNull()?.second?.outputTokens?.coerceAtLeast(1) ?: 1

    CardContainer {
        Column(modifier = Modifier.padding(DS.Spacing.l)) {
            Text(
                text = "Models",
                style = MaterialTheme.typography.labelMedium,
                fontWeight = FontWeight.SemiBold,
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = DS.Opacity.m)
            )
            Spacer(modifier = Modifier.height(DS.Spacing.m))

            sorted.forEach { (name, tokens) ->
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(vertical = DS.Spacing.xs),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        text = name,
                        style = MaterialTheme.typography.labelMedium,
                        fontWeight = FontWeight.Medium,
                        color = MaterialTheme.colorScheme.onSurface,
                        modifier = Modifier.width(72.dp)
                    )

                    val fraction = tokens.outputTokens.toFloat() / maxTokens
                    val colors = modelGradient(name)
                    Box(
                        modifier = Modifier
                            .weight(1f)
                            .height(10.dp)
                    ) {
                        Box(
                            modifier = Modifier
                                .fillMaxWidth(fraction.coerceAtLeast(0.02f))
                                .height(10.dp)
                                .clip(RoundedCornerShape(DS.Radius.s))
                                .background(Brush.horizontalGradient(colors))
                        )
                    }

                    Text(
                        text = formatNumber(tokens.outputTokens.toInt()),
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.onSurface.copy(alpha = DS.Opacity.m),
                        textAlign = TextAlign.End,
                        modifier = Modifier.width(48.dp)
                    )
                }
            }
        }
    }
}

@Composable
private fun PeakHoursSection(stats: UsageStats) {
    val maxCount = stats.hourCounts.values.maxOrNull()?.coerceAtLeast(1) ?: 1

    CardContainer {
        Column(modifier = Modifier.padding(DS.Spacing.l)) {
            Text(
                text = "Peak Hours",
                style = MaterialTheme.typography.labelMedium,
                fontWeight = FontWeight.SemiBold,
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = DS.Opacity.m)
            )
            Spacer(modifier = Modifier.height(DS.Spacing.s))

            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(DS.Size.l),
                horizontalArrangement = Arrangement.spacedBy(2.dp),
                verticalAlignment = Alignment.Bottom
            ) {
                (0 until 24).forEach { hour ->
                    val count = stats.hourCounts["$hour"] ?: stats.hourCounts[hour.toString().padStart(2, '0')] ?: 0
                    val fraction = count.toFloat() / maxCount
                    val intensity = 0.3f + fraction * 0.7f
                    Box(
                        modifier = Modifier
                            .weight(1f)
                            .height((DS.Spacing.xs + (DS.Size.l - DS.Spacing.xs) * fraction))
                            .clip(RoundedCornerShape(topStart = DS.Radius.s, topEnd = DS.Radius.s))
                            .background(ChartBlue.copy(alpha = intensity))
                    )
                }
            }

            Spacer(modifier = Modifier.height(DS.Spacing.xs))
            Row(modifier = Modifier.fillMaxWidth()) {
                Text("12a", style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.3f), modifier = Modifier.weight(1f))
                Text("6a", style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.3f), textAlign = TextAlign.Center, modifier = Modifier.weight(1f))
                Text("12p", style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.3f), textAlign = TextAlign.Center, modifier = Modifier.weight(1f))
                Text("6p", style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.3f), textAlign = TextAlign.Center, modifier = Modifier.weight(1f))
                Text("12a", style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.3f), textAlign = TextAlign.End, modifier = Modifier.weight(1f))
            }
        }
    }
}

@Composable
private fun FooterRow(stats: UsageStats) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(DS.Spacing.l),
        verticalAlignment = Alignment.CenterVertically
    ) {
        stats.firstSessionDate?.let { date ->
            Text(
                text = formatDate(date),
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = DS.Opacity.m)
            )
        }
        stats.longestSession?.let { longest ->
            Text(
                text = "${longest.messageCount} msg record",
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = DS.Opacity.m)
            )
        }
        val peakHour = stats.hourCounts.maxByOrNull { it.value }
        peakHour?.key?.toIntOrNull()?.let { h ->
            Text(
                text = formatHour(h),
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = DS.Opacity.m)
            )
        }
    }
}

@Composable
private fun CardContainer(content: @Composable () -> Unit) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(DS.Radius.m))
            .background(Color.White.copy(alpha = DS.Opacity.s))
            .border(DS.Stroke.s, Color.White.copy(alpha = DS.Opacity.s), RoundedCornerShape(DS.Radius.m))
    ) {
        content()
    }
}

private fun formatNumber(n: Int): String = when {
    n >= 1_000_000 -> String.format("%.1fM", n / 1_000_000.0)
    n >= 1_000 -> String.format("%.1fK", n / 1_000.0)
    else -> "$n"
}

private fun chartDateLabel(dateStr: String): String {
    val parts = dateStr.split("-")
    if (parts.size != 3) return dateStr
    val month = parts[1].toIntOrNull() ?: return dateStr
    val day = parts[2].toIntOrNull() ?: return dateStr
    val months = arrayOf("", "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec")
    val monthName = if (month in 1..12) months[month] else "$month"
    return "$monthName $day"
}

private fun formatDate(dateStr: String): String {
    val parts = dateStr.split("-")
    if (parts.size != 3) return dateStr
    val month = parts[1].toIntOrNull() ?: return dateStr
    val day = parts[2].toIntOrNull() ?: return dateStr
    val year = parts[0].toIntOrNull() ?: return dateStr
    val months = arrayOf("", "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec")
    val monthName = if (month in 1..12) months[month] else "$month"
    return "$monthName $day, $year"
}

private fun formatHour(h: Int): String = when {
    h == 0 -> "12 AM"
    h < 12 -> "$h AM"
    h == 12 -> "12 PM"
    else -> "${h - 12} PM"
}

private fun modelDisplayName(raw: String): String = when {
    raw.contains("opus-4-6") || raw.contains("opus-4.6") -> "Opus 4.6"
    raw.contains("opus-4-5") || raw.contains("opus-4.5") -> "Opus 4.5"
    raw.contains("opus") -> "Opus"
    raw.contains("sonnet-4-6") || raw.contains("sonnet-4.6") -> "Sonnet 4.6"
    raw.contains("sonnet") -> "Sonnet"
    raw.contains("haiku") -> "Haiku"
    else -> raw.substringAfterLast("/").substringAfterLast("-").take(12)
}

private fun modelGradient(name: String): List<Color> = when {
    name.startsWith("Opus 4.6") -> listOf(Color(0xFF5B8DEF), Color(0xFF00BCD4))
    name.startsWith("Opus") -> listOf(Color(0xFF9C27B0), Color(0xFFAB7AE0))
    name.startsWith("Sonnet") -> listOf(Accent, Color(0xFFFFC107))
    name.startsWith("Haiku") -> listOf(Color(0xFF4CAF50), Color(0xFF80CBC4))
    else -> listOf(Color.Gray, Color.Gray.copy(alpha = DS.Opacity.l))
}

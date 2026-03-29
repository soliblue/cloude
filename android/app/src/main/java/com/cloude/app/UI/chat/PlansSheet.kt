package com.cloude.app.UI.chat

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
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
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Archive
import androidx.compose.material.icons.filled.Build
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.NavigateNext
import androidx.compose.material.icons.filled.Science
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
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
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.cloude.app.Models.PlanItem
import com.cloude.app.Utilities.Accent
import com.cloude.app.Utilities.DS

private val STAGE_ORDER = listOf("backlog", "next", "active", "testing", "done")

private data class StageInfo(val label: String, val icon: ImageVector, val color: Color)

private val STAGES = mapOf(
    "backlog" to StageInfo("Backlog", Icons.Default.Archive, Color.Gray),
    "next" to StageInfo("Next", Icons.Default.NavigateNext, Color(0xFF5B9BD5)),
    "active" to StageInfo("Active", Icons.Default.Build, Color(0xFFE5943A)),
    "testing" to StageInfo("Testing", Icons.Default.Science, Color(0xFF9B59B6)),
    "done" to StageInfo("Done", Icons.Default.CheckCircle, Color(0xFF7AB87A))
)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun PlansSheet(
    stages: Map<String, List<PlanItem>>,
    onDelete: (stage: String, filename: String) -> Unit,
    onDismiss: () -> Unit
) {
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    var selectedStage by remember {
        val initial = STAGE_ORDER.firstOrNull { (stages[it]?.size ?: 0) > 0 } ?: "active"
        mutableStateOf(initial)
    }
    var selectedTags by remember { mutableStateOf(emptySet<String>()) }

    val currentPlans = stages[selectedStage] ?: emptyList()
    val availableTags = currentPlans.flatMap { it.tags }.toSet().sorted()
    val filteredPlans = (if (selectedTags.isEmpty()) currentPlans
        else currentPlans.filter { plan -> plan.tags.any { it in selectedTags } })
        .sortedBy { it.priority }

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
        containerColor = MaterialTheme.colorScheme.surfaceVariant
    ) {
        Column(modifier = Modifier.padding(bottom = DS.Spacing.xl)) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = DS.Spacing.l, vertical = DS.Spacing.s),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Row(
                    horizontalArrangement = Arrangement.spacedBy(DS.Spacing.xs),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    STAGE_ORDER.forEachIndexed { i, stage ->
                        if (i > 0) {
                            Box(
                                modifier = Modifier
                                    .width(1.dp)
                                    .height(DS.Icon.m)
                                    .background(MaterialTheme.colorScheme.outline.copy(alpha = 0.2f))
                            )
                        }
                        val info = STAGES[stage] ?: return@forEachIndexed
                        val count = stages[stage]?.size ?: 0
                        val isSelected = stage == selectedStage
                        Row(
                            modifier = Modifier
                                .clip(RoundedCornerShape(DS.Radius.m))
                                .then(if (isSelected) Modifier.background(info.color.copy(alpha = DS.Opacity.s)) else Modifier)
                                .clickable { selectedStage = stage }
                                .padding(horizontal = DS.Spacing.s, vertical = DS.Spacing.xs),
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(DS.Spacing.xs)
                        ) {
                            Icon(
                                imageVector = info.icon,
                                contentDescription = info.label,
                                tint = if (isSelected) info.color else MaterialTheme.colorScheme.onSurface.copy(alpha = DS.Opacity.m),
                                modifier = Modifier.size(DS.Icon.m)
                            )
                            if (isSelected && count > 0) {
                                Text(
                                    text = "$count",
                                    style = MaterialTheme.typography.labelSmall,
                                    fontWeight = FontWeight.SemiBold,
                                    color = info.color
                                )
                            }
                        }
                    }
                }
                IconButton(onClick = onDismiss) {
                    Icon(
                        Icons.Default.Close,
                        contentDescription = "Close",
                        tint = MaterialTheme.colorScheme.onSurface.copy(alpha = DS.Opacity.m)
                    )
                }
            }

            if (availableTags.isNotEmpty()) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .horizontalScroll(rememberScrollState())
                        .padding(horizontal = DS.Spacing.l, vertical = DS.Spacing.s),
                    horizontalArrangement = Arrangement.spacedBy(DS.Spacing.s)
                ) {
                    TagChip(
                        label = "All",
                        isSelected = selectedTags.isEmpty(),
                        color = Accent,
                        onClick = { selectedTags = emptySet() }
                    )
                    availableTags.forEach { tag ->
                        TagChip(
                            label = tag,
                            isSelected = tag in selectedTags,
                            color = tagColor(tag),
                            onClick = {
                                selectedTags = if (tag in selectedTags) selectedTags - tag else selectedTags + tag
                            }
                        )
                    }
                }
            }

            HorizontalDivider(color = MaterialTheme.colorScheme.outline.copy(alpha = 0.2f))

            if (filteredPlans.isEmpty()) {
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(DS.Spacing.xxl),
                    contentAlignment = Alignment.Center
                ) {
                    Text(
                        text = "No plans in $selectedStage",
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurface.copy(alpha = DS.Opacity.m)
                    )
                }
            } else {
                LazyColumn(
                    modifier = Modifier.padding(horizontal = DS.Spacing.l),
                    verticalArrangement = Arrangement.spacedBy(DS.Spacing.m)
                ) {
                    item { Spacer(modifier = Modifier.height(DS.Spacing.s)) }
                    items(filteredPlans, key = { it.filename }) { plan ->
                        PlanCard(
                            plan = plan,
                            stageColor = STAGES[selectedStage]?.color ?: Color.Gray,
                            onDelete = { onDelete(selectedStage, plan.filename) }
                        )
                    }
                    item { Spacer(modifier = Modifier.height(DS.Spacing.l)) }
                }
            }
        }
    }
}

@Composable
private fun TagChip(label: String, isSelected: Boolean, color: Color, onClick: () -> Unit) {
    Text(
        text = label,
        style = MaterialTheme.typography.labelMedium,
        fontWeight = FontWeight.Medium,
        color = if (isSelected) color else MaterialTheme.colorScheme.onSurface.copy(alpha = DS.Opacity.l),
        modifier = Modifier
            .clip(RoundedCornerShape(50))
            .background(if (isSelected) color.copy(alpha = DS.Opacity.s) else MaterialTheme.colorScheme.surface.copy(alpha = 0.5f))
            .clickable(onClick = onClick)
            .padding(horizontal = DS.Spacing.m, vertical = DS.Spacing.xs)
    )
}

@Composable
private fun PlanCard(plan: PlanItem, stageColor: Color, onDelete: () -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(DS.Radius.m))
            .background(MaterialTheme.colorScheme.surface.copy(alpha = 0.5f))
            .padding(DS.Spacing.l),
        verticalAlignment = Alignment.Top
    ) {
        Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(DS.Spacing.xs)) {
            Text(
                text = plan.title,
                style = MaterialTheme.typography.bodyMedium,
                fontWeight = FontWeight.SemiBold,
                color = MaterialTheme.colorScheme.onSurface,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
            if (!plan.description.isNullOrBlank()) {
                Text(
                    text = plan.description,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = DS.Opacity.m),
                    maxLines = 3,
                    overflow = TextOverflow.Ellipsis
                )
            }
            if (plan.tags.isNotEmpty()) {
                Row(
                    horizontalArrangement = Arrangement.spacedBy(DS.Spacing.s),
                    modifier = Modifier.padding(top = DS.Spacing.xs)
                ) {
                    plan.tags.take(5).forEach { tag ->
                        Text(
                            text = tag,
                            style = MaterialTheme.typography.labelSmall,
                            color = tagColor(tag).copy(alpha = DS.Opacity.l),
                            modifier = Modifier
                                .clip(RoundedCornerShape(50))
                                .background(tagColor(tag).copy(alpha = DS.Opacity.s))
                                .padding(horizontal = DS.Spacing.s, vertical = 2.dp)
                        )
                    }
                }
            }
        }
        IconButton(onClick = onDelete, modifier = Modifier.size(DS.Size.m)) {
            Icon(
                Icons.Default.Delete,
                contentDescription = "Delete",
                tint = MaterialTheme.colorScheme.error.copy(alpha = 0.6f),
                modifier = Modifier.size(DS.Icon.m)
            )
        }
    }
}

private fun tagColor(tag: String): Color = when (tag) {
    "ui" -> Color(0xFF5B9BD5)
    "agent" -> Color(0xFF9B59B6)
    "security" -> Color(0xFFE74C3C)
    "reliability" -> Color(0xFFE5943A)
    "heartbeat" -> Color(0xFFE91E8C)
    "memory" -> Color(0xFF7AB87A)
    "autonomy" -> Color(0xFF5C6BC0)
    "plans" -> Color(0xFF26A69A)
    "refactor" -> Color.Gray
    "teams" -> Color(0xFF00BCD4)
    "files" -> Color(0xFF8D6E63)
    "git" -> Color(0xFF66BB6A)
    "tools" -> Color(0xFFFFCA28)
    "input" -> Color(0xFF5B9BD5)
    "markdown" -> Color(0xFF9B59B6)
    "conversations" -> Color(0xFF7AB87A)
    "windows" -> Color(0xFF5C6BC0)
    "messages" -> Color(0xFFE5943A)
    "skills" -> Color(0xFFE91E8C)
    "performance" -> Color(0xFFE74C3C)
    "android" -> Color(0xFF7AB87A)
    "images" -> Color(0xFF26A69A)
    "architecture" -> Color(0xFF5C6BC0)
    else -> Color.Gray
}

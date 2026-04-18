package com.cloude.app.UI.chat

import androidx.compose.foundation.background
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
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Search
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
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.cloude.app.Models.Skill
import com.cloude.app.Utilities.Accent
import com.cloude.app.Utilities.DS
import com.cloude.app.Utilities.PastelGreen

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SkillsSheet(
    skills: List<Skill>,
    onSelect: (String) -> Unit,
    onDismiss: () -> Unit
) {
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    var query by remember { mutableStateOf("") }

    val sorted = skills.sortedByDescending { it.userInvocable }
    val filtered = if (query.isBlank()) sorted
    else sorted.filter { skill ->
        skill.name.contains(query, ignoreCase = true) ||
            skill.description?.contains(query, ignoreCase = true) == true ||
            skill.aliases.any { it.contains(query, ignoreCase = true) }
    }

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
                Text(
                    text = "Skills",
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.SemiBold,
                    color = MaterialTheme.colorScheme.onSurface
                )
                IconButton(onClick = onDismiss) {
                    Icon(
                        Icons.Default.Close,
                        contentDescription = "Close",
                        tint = MaterialTheme.colorScheme.onSurface.copy(alpha = DS.Opacity.m)
                    )
                }
            }

            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = DS.Spacing.l)
                    .clip(RoundedCornerShape(DS.Radius.m))
                    .background(MaterialTheme.colorScheme.surface)
                    .padding(horizontal = DS.Spacing.m, vertical = DS.Spacing.s),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(DS.Spacing.s)
            ) {
                Icon(
                    Icons.Default.Search,
                    contentDescription = null,
                    tint = MaterialTheme.colorScheme.onSurface.copy(alpha = DS.Opacity.m),
                    modifier = Modifier.size(DS.Icon.m)
                )
                Box(modifier = Modifier.weight(1f)) {
                    if (query.isEmpty()) {
                        Text(
                            text = "Search skills...",
                            style = MaterialTheme.typography.bodyMedium,
                            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.4f)
                        )
                    }
                    BasicTextField(
                        value = query,
                        onValueChange = { query = it },
                        textStyle = MaterialTheme.typography.bodyMedium.copy(
                            color = MaterialTheme.colorScheme.onSurface
                        ),
                        singleLine = true,
                        cursorBrush = SolidColor(Accent),
                        modifier = Modifier.fillMaxWidth()
                    )
                }
            }

            Spacer(modifier = Modifier.height(DS.Spacing.s))
            HorizontalDivider(color = MaterialTheme.colorScheme.outline.copy(alpha = 0.2f))

            if (filtered.isEmpty()) {
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(DS.Spacing.xxl),
                    contentAlignment = Alignment.Center
                ) {
                    Text(
                        text = if (query.isBlank()) "No skills available" else "No matching skills",
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurface.copy(alpha = DS.Opacity.m)
                    )
                }
            } else {
                LazyColumn(
                    modifier = Modifier.padding(horizontal = DS.Spacing.l),
                    verticalArrangement = Arrangement.spacedBy(DS.Spacing.s)
                ) {
                    item { Spacer(modifier = Modifier.height(DS.Spacing.s)) }
                    items(filtered, key = { it.name }) { skill ->
                        SkillCard(
                            skill = skill,
                            onTap = {
                                onSelect("/${skill.name}")
                                onDismiss()
                            }
                        )
                    }
                    item { Spacer(modifier = Modifier.height(DS.Spacing.l)) }
                }
            }
        }
    }
}

@Composable
private fun SkillCard(skill: Skill, onTap: () -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(DS.Radius.m))
            .background(MaterialTheme.colorScheme.surface.copy(alpha = 0.5f))
            .clickable(onClick = onTap)
            .padding(DS.Spacing.l),
        verticalAlignment = Alignment.Top
    ) {
        Text(
            text = "\u2726",
            style = MaterialTheme.typography.titleMedium,
            color = Accent,
            modifier = Modifier.padding(end = DS.Spacing.m, top = 2.dp)
        )
        Column(
            modifier = Modifier.weight(1f),
            verticalArrangement = Arrangement.spacedBy(DS.Spacing.xs)
        ) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(DS.Spacing.s)
            ) {
                Text(
                    text = "/${skill.name}",
                    style = MaterialTheme.typography.bodyMedium.copy(
                        fontFamily = FontFamily.Monospace,
                        fontWeight = FontWeight.SemiBold
                    ),
                    color = MaterialTheme.colorScheme.onSurface,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    modifier = Modifier.weight(1f, fill = false)
                )
                if (skill.userInvocable) {
                    Text(
                        text = "invocable",
                        style = MaterialTheme.typography.labelSmall,
                        color = PastelGreen,
                        modifier = Modifier
                            .clip(RoundedCornerShape(50))
                            .background(PastelGreen.copy(alpha = 0.1f))
                            .padding(horizontal = DS.Spacing.s, vertical = 2.dp)
                    )
                }
                if (skill.parameters.isNotEmpty()) {
                    Text(
                        text = "${skill.parameters.size} param${if (skill.parameters.size > 1) "s" else ""}",
                        style = MaterialTheme.typography.labelSmall,
                        color = Accent,
                        modifier = Modifier
                            .clip(RoundedCornerShape(50))
                            .background(Accent.copy(alpha = 0.1f))
                            .padding(horizontal = DS.Spacing.s, vertical = 2.dp)
                    )
                }
            }
            if (skill.description?.isNotBlank() == true) {
                Text(
                    text = skill.description,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = DS.Opacity.m),
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis
                )
            }
            if (skill.aliases.isNotEmpty()) {
                Text(
                    text = "aliases: ${skill.aliases.joinToString(", ")}",
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.4f),
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )
            }
        }
    }
}

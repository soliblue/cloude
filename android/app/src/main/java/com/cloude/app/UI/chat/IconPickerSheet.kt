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
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Search
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
import androidx.compose.ui.graphics.SolidColor
import com.cloude.app.Utilities.Accent
import com.cloude.app.Utilities.DS
import com.cloude.app.Utilities.IconEntry
import com.cloude.app.Utilities.iconCategories

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun IconPickerSheet(
    selectedIcon: String?,
    onSelect: (String) -> Unit,
    onDismiss: () -> Unit
) {
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    var searchQuery by remember { mutableStateOf("") }

    val filtered = remember(searchQuery) {
        if (searchQuery.isBlank()) iconCategories
        else {
            val q = searchQuery.lowercase()
            iconCategories.mapNotNull { (category, icons) ->
                val matches = icons.filter { it.name.replace("_", " ").contains(q) || category.lowercase().contains(q) }
                if (matches.isEmpty()) null else category to matches
            }
        }
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
                    text = "Choose Icon",
                    style = MaterialTheme.typography.titleMedium,
                    color = MaterialTheme.colorScheme.onSurface
                )
                if (selectedIcon != null) {
                    Text(
                        text = "Remove",
                        style = MaterialTheme.typography.labelMedium,
                        color = Accent,
                        modifier = Modifier
                            .clip(RoundedCornerShape(DS.Radius.s))
                            .clickable { onSelect(""); onDismiss() }
                            .padding(horizontal = DS.Spacing.s, vertical = DS.Spacing.xs)
                    )
                }
            }

            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = DS.Spacing.l, vertical = DS.Spacing.xs)
                    .clip(RoundedCornerShape(DS.Radius.m))
                    .background(MaterialTheme.colorScheme.surface)
                    .padding(horizontal = DS.Spacing.m, vertical = DS.Spacing.s),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(DS.Spacing.s)
            ) {
                Icon(
                    imageVector = Icons.Default.Search,
                    contentDescription = null,
                    tint = MaterialTheme.colorScheme.onSurface.copy(alpha = DS.Opacity.m),
                    modifier = Modifier.size(DS.Icon.m)
                )
                BasicTextField(
                    value = searchQuery,
                    onValueChange = { searchQuery = it },
                    modifier = Modifier.weight(1f),
                    textStyle = MaterialTheme.typography.bodyMedium.copy(
                        color = MaterialTheme.colorScheme.onSurface
                    ),
                    cursorBrush = SolidColor(Accent),
                    singleLine = true,
                    decorationBox = { innerTextField ->
                        if (searchQuery.isEmpty()) {
                            Text(
                                text = "Search icons...",
                                style = MaterialTheme.typography.bodyMedium,
                                color = MaterialTheme.colorScheme.onSurface.copy(alpha = DS.Opacity.m)
                            )
                        }
                        innerTextField()
                    }
                )
                if (searchQuery.isNotEmpty()) {
                    Icon(
                        imageVector = Icons.Default.Close,
                        contentDescription = "Clear",
                        tint = MaterialTheme.colorScheme.onSurface.copy(alpha = DS.Opacity.m),
                        modifier = Modifier
                            .size(DS.Icon.m)
                            .clip(CircleShape)
                            .clickable { searchQuery = "" }
                    )
                }
            }

            Spacer(modifier = Modifier.height(DS.Spacing.s))

            LazyColumn(modifier = Modifier.fillMaxWidth()) {
                filtered.forEach { (category, icons) ->
                    item(key = "header_$category") {
                        Text(
                            text = category,
                            style = MaterialTheme.typography.labelSmall,
                            color = MaterialTheme.colorScheme.onSurface.copy(alpha = DS.Opacity.l),
                            modifier = Modifier.padding(
                                start = DS.Spacing.l, top = DS.Spacing.m, bottom = DS.Spacing.xs
                            )
                        )
                    }
                    item(key = "grid_$category") {
                        IconGrid(
                            icons = icons,
                            selectedIcon = selectedIcon,
                            onSelect = { onSelect(it); onDismiss() }
                        )
                    }
                }
                item { Spacer(modifier = Modifier.height(DS.Spacing.l)) }
            }
        }
    }
}

@Composable
private fun IconGrid(
    icons: List<IconEntry>,
    selectedIcon: String?,
    onSelect: (String) -> Unit
) {
    val rows = icons.chunked(6)
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = DS.Spacing.m),
        verticalArrangement = Arrangement.spacedBy(DS.Spacing.s)
    ) {
        rows.forEach { row ->
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceEvenly
            ) {
                row.forEach { entry ->
                    val isSelected = entry.name == selectedIcon
                    Box(
                        modifier = Modifier
                            .size(DS.Size.l)
                            .clip(RoundedCornerShape(DS.Radius.s))
                            .background(if (isSelected) Accent.copy(alpha = 0.3f) else MaterialTheme.colorScheme.surface.copy(alpha = 0.5f))
                            .clickable { onSelect(entry.name) },
                        contentAlignment = Alignment.Center
                    ) {
                        Icon(
                            imageVector = entry.icon,
                            contentDescription = entry.name,
                            tint = if (isSelected) Accent else MaterialTheme.colorScheme.onSurface.copy(alpha = DS.Opacity.l),
                            modifier = Modifier.size(DS.Icon.l)
                        )
                    }
                }
                repeat(6 - row.size) {
                    Spacer(modifier = Modifier.size(DS.Size.l))
                }
            }
        }
    }
}

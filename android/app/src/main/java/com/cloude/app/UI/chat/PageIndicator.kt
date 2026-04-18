package com.cloude.app.UI.chat

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Close
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import com.cloude.app.Models.ChatWindow
import com.cloude.app.Utilities.Accent
import com.cloude.app.Utilities.DS
import com.cloude.app.Utilities.PastelRed

@OptIn(ExperimentalFoundationApi::class)
@Composable
fun PageIndicator(
    windows: List<ChatWindow>,
    activeIndex: Int,
    canAdd: Boolean,
    onPageSelected: (Int) -> Unit,
    onAddWindow: () -> Unit,
    onRemoveWindow: (String) -> Unit,
    modifier: Modifier = Modifier
) {
    if (windows.size <= 1 && !canAdd) return

    Row(
        modifier = modifier
            .background(MaterialTheme.colorScheme.surfaceVariant)
            .padding(horizontal = DS.Spacing.l, vertical = DS.Spacing.xs),
        horizontalArrangement = Arrangement.spacedBy(DS.Spacing.s, Alignment.CenterHorizontally),
        verticalAlignment = Alignment.CenterVertically
    ) {
        windows.forEachIndexed { index, window ->
            var showMenu by remember { mutableStateOf(false) }
            Box {
                Box(
                    modifier = Modifier
                        .size(DS.Spacing.s)
                        .clip(CircleShape)
                        .background(if (index == activeIndex) Accent else MaterialTheme.colorScheme.onSurface.copy(alpha = DS.Opacity.m))
                        .combinedClickable(
                            onClick = { onPageSelected(index) },
                            onLongClick = { if (windows.size > 1) showMenu = true }
                        )
                )
                DropdownMenu(
                    expanded = showMenu,
                    onDismissRequest = { showMenu = false }
                ) {
                    DropdownMenuItem(
                        text = { Text("Remove") },
                        leadingIcon = { Icon(Icons.Default.Close, null, tint = PastelRed) },
                        onClick = {
                            showMenu = false
                            onRemoveWindow(window.id)
                        }
                    )
                }
            }
        }

        if (canAdd) {
            Box(
                modifier = Modifier
                    .size(DS.Spacing.m)
                    .clip(CircleShape)
                    .background(MaterialTheme.colorScheme.onSurface.copy(alpha = DS.Opacity.s))
                    .clickable { onAddWindow() },
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    Icons.Default.Add,
                    contentDescription = "Add window",
                    tint = MaterialTheme.colorScheme.onSurface.copy(alpha = DS.Opacity.l),
                    modifier = Modifier.size(DS.Spacing.s)
                )
            }
        }
    }
}

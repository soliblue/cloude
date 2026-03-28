package com.cloude.app.UI.chat

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.Chat
import androidx.compose.material.icons.filled.Difference
import androidx.compose.material.icons.filled.Folder
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import com.cloude.app.Models.WindowType
import com.cloude.app.Utilities.Accent
import com.cloude.app.Utilities.DS

@Composable
fun WindowTabBar(
    activeType: WindowType,
    onTypeSelected: (WindowType) -> Unit,
    modifier: Modifier = Modifier
) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            .background(MaterialTheme.colorScheme.surfaceVariant)
            .padding(horizontal = DS.Spacing.l, vertical = DS.Spacing.xs),
        horizontalArrangement = Arrangement.Center,
        verticalAlignment = Alignment.CenterVertically
    ) {
        val tabs = listOf(
            WindowType.Chat to Icons.AutoMirrored.Filled.Chat,
            WindowType.Files to Icons.Default.Folder,
            WindowType.GitChanges to Icons.Default.Difference
        )

        Row(
            horizontalArrangement = Arrangement.spacedBy(DS.Spacing.xs)
        ) {
            tabs.forEach { (type, icon) ->
                val isActive = type == activeType
                Box(
                    modifier = Modifier
                        .clip(RoundedCornerShape(DS.Radius.m))
                        .then(
                            if (isActive) Modifier.background(Accent.copy(alpha = DS.Opacity.s))
                            else Modifier
                        )
                        .clickable { onTypeSelected(type) }
                        .padding(horizontal = DS.Spacing.m, vertical = DS.Spacing.s),
                    contentAlignment = Alignment.Center
                ) {
                    Icon(
                        imageVector = icon,
                        contentDescription = type.name,
                        tint = if (isActive) Accent else MaterialTheme.colorScheme.onSurface.copy(alpha = DS.Opacity.m),
                        modifier = Modifier.size(DS.Icon.l)
                    )
                }
            }
        }
    }
}

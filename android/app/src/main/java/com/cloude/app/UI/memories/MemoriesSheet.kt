package com.cloude.app.UI.memories

import android.util.Log
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.expandVertically
import androidx.compose.animation.shrinkVertically
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
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ChevronRight
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
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.cloude.app.Models.MemoryItem
import com.cloude.app.Models.MemorySection
import com.cloude.app.Models.ParsedMemorySection
import com.cloude.app.Services.MemoryParser
import com.cloude.app.Utilities.Accent
import com.cloude.app.Utilities.DS
import java.text.SimpleDateFormat
import java.util.Locale

private val sfSymbolMap = mapOf(
    "brain" to "\uD83E\uDDE0", "brain.head.profile" to "\uD83E\uDDE0",
    "person" to "\uD83D\uDC64", "person.fill" to "\uD83D\uDC64",
    "heart" to "\u2764\uFE0F", "heart.fill" to "\u2764\uFE0F",
    "star" to "\u2B50", "star.fill" to "\u2B50",
    "bolt" to "\u26A1", "bolt.fill" to "\u26A1",
    "gear" to "\u2699\uFE0F", "gearshape" to "\u2699\uFE0F",
    "hammer" to "\uD83D\uDD28", "hammer.fill" to "\uD83D\uDD28",
    "wrench" to "\uD83D\uDD27", "wrench.fill" to "\uD83D\uDD27",
    "flag" to "\uD83C\uDFF3\uFE0F", "flag.fill" to "\uD83C\uDFF3\uFE0F",
    "bookmark" to "\uD83D\uDD16", "bookmark.fill" to "\uD83D\uDD16",
    "book" to "\uD83D\uDCD6", "book.fill" to "\uD83D\uDCD6",
    "doc" to "\uD83D\uDCC4", "doc.fill" to "\uD83D\uDCC4",
    "folder" to "\uD83D\uDCC1", "folder.fill" to "\uD83D\uDCC1",
    "tray" to "\uD83D\uDCE5", "tray.fill" to "\uD83D\uDCE5",
    "archivebox" to "\uD83D\uDCE6", "lightbulb" to "\uD83D\uDCA1",
    "camera" to "\uD83D\uDCF7", "eye" to "\uD83D\uDC41\uFE0F",
    "checkmark.circle" to "\u2705", "checkmark.circle.fill" to "\u2705",
    "xmark.circle" to "\u274C", "clock" to "\uD83D\uDD52",
    "calendar" to "\uD83D\uDCC5", "link" to "\uD83D\uDD17",
    "paintbrush" to "\uD83D\uDD8C\uFE0F", "paintbrush.fill" to "\uD83D\uDD8C\uFE0F",
    "terminal" to "\uD83D\uDCBB", "terminal.fill" to "\uD83D\uDCBB",
    "globe" to "\uD83C\uDF10", "lock" to "\uD83D\uDD12",
    "key" to "\uD83D\uDD11", "message" to "\uD83D\uDCAC",
    "envelope" to "\u2709\uFE0F", "bell" to "\uD83D\uDD14",
    "tag" to "\uD83C\uDFF7\uFE0F", "house" to "\uD83C\uDFE0",
    "puzzlepiece" to "\uD83E\uDDE9", "sparkles" to "\u2728",
    "flame" to "\uD83D\uDD25", "leaf" to "\uD83C\uDF43"
)

private fun iconForSymbol(symbol: String?): String =
    symbol?.let { sfSymbolMap[it] } ?: "\uD83D\uDCCC"

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MemoriesSheet(
    rawSections: List<MemorySection>,
    onDismiss: () -> Unit
) {
    Log.d("Cloude", "MemoriesSheet composing with ${rawSections.size} raw sections")

    val sections = remember(rawSections) {
        try {
            MemoryParser.parse(rawSections).also {
                Log.d("Cloude", "MemoryParser produced ${it.size} parsed sections")
            }
        } catch (e: Exception) {
            Log.e("Cloude", "MemoryParser crashed: ${e.message}", e)
            emptyList()
        }
    }

    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
        containerColor = MaterialTheme.colorScheme.background
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = DS.Spacing.l, vertical = DS.Spacing.s),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                text = "Memories",
                style = MaterialTheme.typography.titleLarge,
                color = MaterialTheme.colorScheme.onBackground
            )
            IconButton(onClick = onDismiss) {
                Icon(
                    Icons.Default.Close,
                    contentDescription = "Close",
                    tint = MaterialTheme.colorScheme.onSurface
                )
            }
        }

        if (sections.isEmpty()) {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(vertical = DS.Spacing.xxl),
                contentAlignment = Alignment.Center
            ) {
                Text(
                    text = "No memories yet",
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = DS.Opacity.s)
                )
            }
        } else {
            LazyColumn(
                modifier = Modifier.padding(horizontal = DS.Spacing.l),
                verticalArrangement = Arrangement.spacedBy(DS.Spacing.m)
            ) {
                itemsIndexed(sections) { index, section ->
                    MemorySectionCard(section = section, depth = 0)
                }
                item { Spacer(modifier = Modifier.height(DS.Spacing.xxl)) }
            }
        }
    }
}

@Composable
private fun MemorySectionCard(section: ParsedMemorySection, depth: Int) {
    var expanded by remember { mutableStateOf(false) }
    val bgAlpha = if (depth == 0) 1f else DS.Opacity.l
    val indent = depth * DS.Spacing.m.value

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(if (depth == 0) DS.Radius.m else DS.Radius.s))
            .background(MaterialTheme.colorScheme.surfaceVariant.copy(alpha = bgAlpha))
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .clickable { expanded = !expanded }
                .padding(
                    start = DS.Spacing.l + indent.dp,
                    end = DS.Spacing.l,
                    top = if (depth == 0) DS.Spacing.l else DS.Spacing.s,
                    bottom = if (depth == 0) DS.Spacing.l else DS.Spacing.s
                ),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(if (depth == 0) DS.Spacing.m else DS.Spacing.s)
        ) {
            Icon(
                Icons.Default.ChevronRight,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.onSurface.copy(alpha = DS.Opacity.s),
                modifier = Modifier
                    .size(DS.Icon.s)
                    .rotate(if (expanded) 90f else 0f)
            )

            Text(
                text = iconForSymbol(section.icon),
                style = MaterialTheme.typography.bodyMedium
            )

            Text(
                text = section.title,
                style = MaterialTheme.typography.bodyMedium,
                fontWeight = if (depth == 0) FontWeight.SemiBold else FontWeight.Medium,
                color = MaterialTheme.colorScheme.onSurface,
                modifier = Modifier.weight(1f)
            )

            Text(
                text = "${section.childCount}",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = DS.Opacity.s)
            )
        }

        AnimatedVisibility(
            visible = expanded,
            enter = expandVertically(),
            exit = shrinkVertically()
        ) {
            Column(
                modifier = Modifier.padding(
                    start = DS.Spacing.m,
                    end = DS.Spacing.m,
                    bottom = DS.Spacing.m
                ),
                verticalArrangement = Arrangement.spacedBy(DS.Spacing.s)
            ) {
                section.subsections.forEach { sub ->
                    MemorySectionCard(section = sub, depth = depth + 1)
                }
                section.items.forEach { item ->
                    MemoryItemCard(item = item)
                }
            }
        }
    }
}

@Composable
private fun MemoryItemCard(item: MemoryItem) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(DS.Radius.s))
            .background(MaterialTheme.colorScheme.surfaceVariant.copy(alpha = DS.Opacity.l))
            .padding(horizontal = DS.Spacing.m, vertical = DS.Spacing.m),
        verticalArrangement = Arrangement.spacedBy(DS.Spacing.xs)
    ) {
        item.timestamp?.let { date ->
            Text(
                text = SimpleDateFormat("MMM d, yyyy", Locale.getDefault()).format(date),
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = DS.Opacity.s)
            )
        }
        Text(
            text = item.content,
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurface
        )
    }
}

@Composable
fun MemoriesScreen(
    sections: List<MemorySection>?,
    modifier: Modifier = Modifier
) {
    val parsed = remember(sections) {
        sections?.let {
            try { MemoryParser.parse(it) } catch (_: Exception) { emptyList() }
        }
    }

    Column(
        modifier = modifier
            .fillMaxWidth()
            .background(MaterialTheme.colorScheme.background)
            .padding(DS.Spacing.l)
    ) {
        if (parsed == null) {
            Box(
                modifier = Modifier.fillMaxWidth().weight(1f),
                contentAlignment = Alignment.Center
            ) {
                androidx.compose.material3.CircularProgressIndicator(
                    color = Accent,
                    modifier = Modifier.size(DS.Size.m)
                )
            }
        } else if (parsed.isEmpty()) {
            Box(
                modifier = Modifier.fillMaxWidth().weight(1f),
                contentAlignment = Alignment.Center
            ) {
                Text(
                    text = "No memories yet",
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = DS.Opacity.m)
                )
            }
        } else {
            LazyColumn(
                verticalArrangement = Arrangement.spacedBy(DS.Spacing.m)
            ) {
                itemsIndexed(parsed) { _, section ->
                    MemorySectionCard(section = section, depth = 0)
                }
                item { Spacer(modifier = Modifier.height(DS.Spacing.xxl)) }
            }
        }
    }
}

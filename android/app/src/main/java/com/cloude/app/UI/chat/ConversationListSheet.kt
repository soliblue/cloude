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
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Delete
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
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.text.withStyle
import com.cloude.app.Models.Conversation
import com.cloude.app.Models.ConversationStore
import com.cloude.app.Utilities.Accent
import com.cloude.app.Utilities.DS

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ConversationListSheet(
    conversationStore: ConversationStore,
    activeConversationId: String,
    onSelect: (Conversation) -> Unit,
    onNew: () -> Unit,
    onDelete: (Conversation) -> Unit,
    onDismiss: () -> Unit
) {
    val conversations by conversationStore.conversations.collectAsState()
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    var searchQuery by remember { mutableStateOf("") }

    val filtered = remember(conversations, searchQuery) {
        if (searchQuery.isBlank()) {
            conversations.map { it to null as String? }
        } else {
            val q = searchQuery.lowercase()
            conversations.mapNotNull { conv ->
                when {
                    conv.name.lowercase().contains(q) -> conv to null
                    conv.workingDirectory?.lowercase()?.contains(q) == true -> conv to null
                    else -> {
                        val match = conv.messages.firstOrNull { it.text.lowercase().contains(q) }
                        if (match != null) conv to matchSnippet(match.text, q) else null
                    }
                }
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
                    text = "Conversations",
                    style = MaterialTheme.typography.titleMedium,
                    color = MaterialTheme.colorScheme.onSurface
                )
                IconButton(onClick = {
                    onNew()
                    onDismiss()
                }) {
                    Icon(
                        imageVector = Icons.Default.Add,
                        contentDescription = "New conversation",
                        tint = Accent
                    )
                }
            }

            SearchBar(
                query = searchQuery,
                onQueryChange = { searchQuery = it },
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = DS.Spacing.l, vertical = DS.Spacing.xs)
            )

            HorizontalDivider(color = MaterialTheme.colorScheme.outline.copy(alpha = 0.2f))

            if (filtered.isEmpty()) {
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(DS.Spacing.xxl),
                    contentAlignment = Alignment.Center
                ) {
                    Text(
                        text = if (searchQuery.isBlank()) "No conversations yet"
                               else "No conversations found",
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurface.copy(alpha = DS.Opacity.m)
                    )
                }
            } else {
                LazyColumn {
                    items(filtered, key = { it.first.id }) { (conv, snippet) ->
                        ConversationRow(
                            conversation = conv,
                            isActive = conv.id == activeConversationId,
                            matchSnippet = snippet,
                            onTap = {
                                onSelect(conv)
                                onDismiss()
                            },
                            onDelete = { onDelete(conv) }
                        )
                    }
                    item { Spacer(modifier = Modifier.height(DS.Spacing.l)) }
                }
            }
        }
    }
}

@Composable
private fun SearchBar(query: String, onQueryChange: (String) -> Unit, modifier: Modifier = Modifier) {
    val focusRequester = remember { FocusRequester() }

    Row(
        modifier = modifier
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
            value = query,
            onValueChange = onQueryChange,
            modifier = Modifier
                .weight(1f)
                .focusRequester(focusRequester),
            textStyle = MaterialTheme.typography.bodyMedium.copy(
                color = MaterialTheme.colorScheme.onSurface
            ),
            cursorBrush = SolidColor(Accent),
            singleLine = true,
            decorationBox = { innerTextField ->
                if (query.isEmpty()) {
                    Text(
                        text = "Search conversations...",
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurface.copy(alpha = DS.Opacity.m)
                    )
                }
                innerTextField()
            }
        )
        if (query.isNotEmpty()) {
            Icon(
                imageVector = Icons.Default.Close,
                contentDescription = "Clear",
                tint = MaterialTheme.colorScheme.onSurface.copy(alpha = DS.Opacity.m),
                modifier = Modifier
                    .size(DS.Icon.m)
                    .clip(CircleShape)
                    .clickable { onQueryChange("") }
            )
        }
    }
}

@Composable
private fun ConversationRow(
    conversation: Conversation,
    isActive: Boolean,
    matchSnippet: String? = null,
    onTap: () -> Unit,
    onDelete: () -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onTap)
            .background(if (isActive) Accent.copy(alpha = 0.1f) else MaterialTheme.colorScheme.surfaceVariant)
            .padding(horizontal = DS.Spacing.l, vertical = DS.Spacing.m),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Box(
            modifier = Modifier
                .size(DS.Size.m)
                .clip(CircleShape)
                .background(if (isActive) Accent else MaterialTheme.colorScheme.outline.copy(alpha = 0.3f)),
            contentAlignment = Alignment.Center
        ) {
            Text(
                text = conversation.name.take(1),
                style = MaterialTheme.typography.labelSmall,
                color = if (isActive) MaterialTheme.colorScheme.onPrimary
                       else MaterialTheme.colorScheme.onSurface
            )
        }

        Spacer(modifier = Modifier.width(DS.Spacing.m))

        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = conversation.name,
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurface,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
            Row(horizontalArrangement = Arrangement.spacedBy(DS.Spacing.s)) {
                Text(
                    text = "${conversation.messages.size} msgs",
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = DS.Opacity.m)
                )
                if (conversation.totalCost > 0) {
                    Text(
                        text = "$${String.format("%.2f", conversation.totalCost)}",
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.onSurface.copy(alpha = DS.Opacity.m)
                    )
                }
                Text(
                    text = formatRelativeTime(conversation.lastMessageAt),
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = DS.Opacity.m)
                )
            }
            if (matchSnippet != null) {
                Text(
                    text = buildAnnotatedString {
                        withStyle(SpanStyle(color = MaterialTheme.colorScheme.onSurface.copy(alpha = DS.Opacity.s))) {
                            append(matchSnippet)
                        }
                    },
                    style = MaterialTheme.typography.labelSmall,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    modifier = Modifier.padding(top = DS.Spacing.xs)
                )
            }
        }

        if (!isActive) {
            IconButton(onClick = onDelete, modifier = Modifier.size(DS.Size.m)) {
                Icon(
                    imageVector = Icons.Default.Delete,
                    contentDescription = "Delete",
                    tint = MaterialTheme.colorScheme.error.copy(alpha = 0.6f),
                    modifier = Modifier.size(DS.Icon.m)
                )
            }
        }
    }
}

private fun matchSnippet(text: String, query: String): String {
    val flat = text.replace('\n', ' ')
    val idx = flat.lowercase().indexOf(query)
    if (idx < 0) return flat.take(80)
    val start = maxOf(0, idx - 30)
    val end = minOf(flat.length, idx + query.length + 50)
    val prefix = if (start > 0) "..." else ""
    val suffix = if (end < flat.length) "..." else ""
    return "$prefix${flat.substring(start, end)}$suffix"
}

private fun formatRelativeTime(timestamp: Long): String {
    val diff = System.currentTimeMillis() - timestamp
    val minutes = diff / 60_000
    val hours = minutes / 60
    val days = hours / 24
    return when {
        minutes < 1 -> "now"
        minutes < 60 -> "${minutes}m"
        hours < 24 -> "${hours}h"
        days < 7 -> "${days}d"
        else -> "${days / 7}w"
    }
}

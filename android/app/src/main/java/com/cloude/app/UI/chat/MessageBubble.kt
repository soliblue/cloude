package com.cloude.app.UI.chat

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextAlign
import com.cloude.app.Models.ChatMessage
import com.cloude.app.Utilities.Accent
import com.cloude.app.Utilities.DS

@OptIn(ExperimentalLayoutApi::class)
@Composable
fun MessageBubble(message: ChatMessage, modifier: Modifier = Modifier) {
    Column(
        modifier = modifier
            .fillMaxWidth()
            .padding(
                start = if (message.isUser) DS.Spacing.xxl else DS.Spacing.xs,
                end = if (message.isUser) DS.Spacing.xs else DS.Spacing.xxl
            )
    ) {
        if (message.toolCalls.isNotEmpty()) {
            FlowRow(
                modifier = Modifier.padding(bottom = DS.Spacing.xs),
                horizontalArrangement = Arrangement.spacedBy(DS.Spacing.xs),
                verticalArrangement = Arrangement.spacedBy(DS.Spacing.xs)
            ) {
                message.toolCalls.forEach { toolCall ->
                    ToolCallLabel(toolCall = toolCall)
                }
            }
        }

        if (message.imageCount > 0 && message.isUser) {
            Text(
                text = "\uD83D\uDDBC ${message.imageCount} image${if (message.imageCount > 1) "s" else ""} attached",
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = DS.Opacity.m),
                textAlign = TextAlign.End,
                modifier = Modifier.fillMaxWidth().padding(bottom = DS.Spacing.xs)
            )
        }

        if (message.text.isNotEmpty()) {
            if (message.isUser) {
                Text(
                    text = message.text,
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onPrimary,
                    textAlign = TextAlign.End,
                    modifier = Modifier
                        .background(Accent.copy(alpha = 0.85f), RoundedCornerShape(DS.Radius.l))
                        .padding(horizontal = DS.Spacing.m, vertical = DS.Spacing.s)
                        .fillMaxWidth()
                )
            } else {
                MarkdownText(
                    text = message.text,
                    color = MaterialTheme.colorScheme.onSurface,
                    modifier = Modifier
                        .background(
                            MaterialTheme.colorScheme.surfaceVariant,
                            RoundedCornerShape(DS.Radius.l)
                        )
                        .padding(horizontal = DS.Spacing.m, vertical = DS.Spacing.s)
                )
            }
        }

        if (message.costUsd != null) {
            Row(
                modifier = Modifier.padding(top = DS.Spacing.xs),
                horizontalArrangement = Arrangement.spacedBy(DS.Spacing.s)
            ) {
                message.model?.let {
                    Text(
                        text = it,
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.onSurface.copy(alpha = DS.Opacity.m)
                    )
                }
                Text(
                    text = "$${String.format("%.4f", message.costUsd)}",
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = DS.Opacity.m)
                )
            }
        }
    }
}

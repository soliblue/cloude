package com.cloude.app.UI.chat

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Build
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextOverflow
import com.cloude.app.Models.ToolCall
import com.cloude.app.Models.ToolCallState
import com.cloude.app.Utilities.Accent
import com.cloude.app.Utilities.DS
import com.cloude.app.Utilities.PastelGreen

@Composable
fun ToolCallLabel(toolCall: ToolCall, modifier: Modifier = Modifier) {
    val isExecuting = toolCall.state == ToolCallState.executing
    val summary = toolCall.resultSummary ?: toolCall.input?.take(60) ?: ""

    Row(
        modifier = modifier
            .background(
                MaterialTheme.colorScheme.surfaceVariant.copy(alpha = DS.Opacity.l),
                RoundedCornerShape(DS.Radius.s)
            )
            .padding(horizontal = DS.Spacing.s, vertical = DS.Spacing.xs),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(DS.Spacing.xs)
    ) {
        if (isExecuting) {
            CircularProgressIndicator(
                modifier = Modifier.size(DS.Icon.s),
                strokeWidth = DS.Stroke.m,
                color = Accent
            )
        } else {
            Icon(
                imageVector = Icons.Default.CheckCircle,
                contentDescription = null,
                modifier = Modifier.size(DS.Icon.s),
                tint = PastelGreen
            )
        }

        Text(
            text = toolCall.name,
            style = MaterialTheme.typography.labelSmall,
            color = MaterialTheme.colorScheme.onSurface
        )

        if (summary.isNotEmpty()) {
            Text(
                text = summary,
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = DS.Opacity.m),
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
        }
    }
}

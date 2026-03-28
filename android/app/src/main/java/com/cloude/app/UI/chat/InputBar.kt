package com.cloude.app.UI.chat

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.Send
import androidx.compose.material.icons.filled.Stop
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
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
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.text.input.ImeAction
import com.cloude.app.Utilities.Accent
import com.cloude.app.Utilities.DS
import com.cloude.app.Utilities.PastelRed

@Composable
fun InputBar(
    isRunning: Boolean,
    currentEffort: String?,
    currentModel: String?,
    onSend: (String) -> Unit,
    onAbort: () -> Unit,
    onEffortChange: (String?) -> Unit,
    onModelChange: (String?) -> Unit,
    modifier: Modifier = Modifier
) {
    var text by remember { mutableStateOf("") }

    Column(modifier = modifier) {
        Row(
            modifier = Modifier.padding(bottom = DS.Spacing.xs),
            horizontalArrangement = Arrangement.spacedBy(DS.Spacing.xs)
        ) {
            PickerChip(
                label = currentModel?.replaceFirstChar { it.uppercase() } ?: "Opus",
                isDefault = currentModel == null,
                onClick = {
                    val models = listOf(null, "opus", "sonnet", "haiku")
                    val idx = models.indexOf(currentModel)
                    onModelChange(models[(idx + 1) % models.size])
                }
            )
            PickerChip(
                label = when (currentEffort) {
                    "low" -> "Low"
                    "medium" -> "Med"
                    "high" -> "High"
                    "max" -> "Max"
                    else -> "Auto"
                },
                isDefault = currentEffort == null,
                onClick = {
                    val efforts = listOf(null, "low", "medium", "high", "max")
                    val idx = efforts.indexOf(currentEffort)
                    onEffortChange(efforts[(idx + 1) % efforts.size])
                }
            )
        }

        Row(
            modifier = Modifier
                .background(
                    MaterialTheme.colorScheme.surfaceVariant,
                    RoundedCornerShape(DS.Radius.l)
                )
                .padding(horizontal = DS.Spacing.m, vertical = DS.Spacing.s),
            verticalAlignment = Alignment.CenterVertically
        ) {
            BasicTextField(
                value = text,
                onValueChange = { text = it },
                modifier = Modifier
                    .weight(1f)
                    .padding(vertical = DS.Spacing.xs),
                textStyle = MaterialTheme.typography.bodyMedium.copy(
                    color = MaterialTheme.colorScheme.onSurface
                ),
                cursorBrush = SolidColor(Accent),
                keyboardOptions = KeyboardOptions(imeAction = ImeAction.Send),
                keyboardActions = KeyboardActions(onSend = {
                    if (text.isNotBlank() && !isRunning) {
                        onSend(text)
                        text = ""
                    }
                }),
                decorationBox = { innerTextField ->
                    if (text.isEmpty()) {
                        Text(
                            text = "Message...",
                            style = MaterialTheme.typography.bodyMedium,
                            color = MaterialTheme.colorScheme.onSurface.copy(alpha = DS.Opacity.m)
                        )
                    }
                    innerTextField()
                }
            )

            if (isRunning) {
                IconButton(onClick = onAbort) {
                    Icon(
                        imageVector = Icons.Default.Stop,
                        contentDescription = "Stop",
                        tint = PastelRed
                    )
                }
            } else {
                IconButton(
                    onClick = {
                        if (text.isNotBlank()) {
                            onSend(text)
                            text = ""
                        }
                    },
                    enabled = text.isNotBlank()
                ) {
                    Icon(
                        imageVector = Icons.AutoMirrored.Filled.Send,
                        contentDescription = "Send",
                        tint = if (text.isNotBlank()) Accent
                               else MaterialTheme.colorScheme.onSurface.copy(alpha = DS.Opacity.s)
                    )
                }
            }
        }
    }
}

@Composable
private fun PickerChip(label: String, isDefault: Boolean, onClick: () -> Unit) {
    Text(
        text = label,
        style = MaterialTheme.typography.labelSmall,
        color = if (isDefault) MaterialTheme.colorScheme.onSurface.copy(alpha = DS.Opacity.m)
               else Accent,
        modifier = Modifier
            .clip(RoundedCornerShape(DS.Radius.m))
            .background(
                if (isDefault) MaterialTheme.colorScheme.surfaceVariant
                else Accent.copy(alpha = 0.15f)
            )
            .clickable(onClick = onClick)
            .padding(horizontal = DS.Spacing.m, vertical = DS.Spacing.xs)
    )
}

package com.cloude.app.UI.chat

import androidx.compose.foundation.background
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.cloude.app.Models.ToolCall
import com.cloude.app.Utilities.DS
import com.cloude.app.Utilities.PastelGreen
import com.cloude.app.Utilities.PastelRed

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ToolDetailSheet(
    toolCall: ToolCall,
    onDismiss: () -> Unit
) {
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
        containerColor = MaterialTheme.colorScheme.surfaceVariant
    ) {
        Column(
            modifier = Modifier
                .padding(bottom = DS.Spacing.xl)
                .verticalScroll(rememberScrollState())
        ) {
            Text(
                text = toolCall.name,
                style = MaterialTheme.typography.titleMedium,
                color = MaterialTheme.colorScheme.onSurface,
                modifier = Modifier.padding(horizontal = DS.Spacing.l, vertical = DS.Spacing.s)
            )

            toolCall.editInfo?.filePath?.let { path ->
                Text(
                    text = path,
                    style = MaterialTheme.typography.labelSmall.copy(fontFamily = FontFamily.Monospace),
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = DS.Opacity.m),
                    modifier = Modifier.padding(horizontal = DS.Spacing.l, vertical = DS.Spacing.xs)
                )
            }

            HorizontalDivider(
                color = MaterialTheme.colorScheme.outline.copy(alpha = 0.2f),
                modifier = Modifier.padding(vertical = DS.Spacing.s)
            )

            if (toolCall.editInfo != null) {
                val edit = toolCall.editInfo!!
                SectionLabel("Changes")
                UnifiedDiffBlock(
                    oldString = edit.oldString,
                    newString = edit.newString
                )
            } else if (toolCall.input != null) {
                SectionLabel("Input")
                CodeBlock(toolCall.input)
            }

            if (toolCall.resultSummary != null) {
                Spacer(modifier = Modifier.height(DS.Spacing.m))
                SectionLabel("Summary")
                Text(
                    text = toolCall.resultSummary!!,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurface,
                    modifier = Modifier.padding(horizontal = DS.Spacing.l)
                )
            }

            if (toolCall.resultOutput != null) {
                Spacer(modifier = Modifier.height(DS.Spacing.m))
                SectionLabel("Output")
                CodeBlock(toolCall.resultOutput!!)
            }

            Spacer(modifier = Modifier.height(DS.Spacing.l))
        }
    }
}

@Composable
private fun SectionLabel(text: String) {
    Text(
        text = text,
        style = MaterialTheme.typography.labelSmall,
        color = MaterialTheme.colorScheme.onSurface.copy(alpha = DS.Opacity.m),
        modifier = Modifier.padding(horizontal = DS.Spacing.l, vertical = DS.Spacing.xs)
    )
}

@Composable
private fun CodeBlock(text: String) {
    Text(
        text = text,
        style = MaterialTheme.typography.bodySmall.copy(
            fontFamily = FontFamily.Monospace,
            lineHeight = 18.sp
        ),
        color = MaterialTheme.colorScheme.onSurface,
        modifier = Modifier
            .padding(horizontal = DS.Spacing.l)
            .fillMaxWidth()
            .background(MaterialTheme.colorScheme.surface, RoundedCornerShape(DS.Radius.m))
            .horizontalScroll(rememberScrollState())
            .padding(DS.Spacing.m)
    )
}

@Composable
private fun UnifiedDiffBlock(oldString: String?, newString: String?) {
    val monoStyle = MaterialTheme.typography.bodySmall.copy(
        fontFamily = FontFamily.Monospace,
        lineHeight = 18.sp
    )
    val textColor = MaterialTheme.colorScheme.onSurface

    Column(
        modifier = Modifier
            .padding(horizontal = DS.Spacing.l)
            .fillMaxWidth()
            .background(MaterialTheme.colorScheme.surface, RoundedCornerShape(DS.Radius.m))
            .horizontalScroll(rememberScrollState())
            .padding(vertical = DS.Spacing.xs)
    ) {
        oldString?.lines()?.forEach { line ->
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .background(PastelRed.copy(alpha = 0.1f))
                    .padding(horizontal = DS.Spacing.s, vertical = 1.dp)
            ) {
                Text(
                    text = "-",
                    style = monoStyle,
                    color = PastelRed,
                    modifier = Modifier.width(16.dp)
                )
                Text(
                    text = line,
                    style = monoStyle,
                    color = textColor
                )
            }
        }
        newString?.lines()?.forEach { line ->
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .background(PastelGreen.copy(alpha = 0.1f))
                    .padding(horizontal = DS.Spacing.s, vertical = 1.dp)
            ) {
                Text(
                    text = "+",
                    style = monoStyle,
                    color = PastelGreen,
                    modifier = Modifier.width(16.dp)
                )
                Text(
                    text = line,
                    style = monoStyle,
                    color = textColor
                )
            }
        }
    }
}

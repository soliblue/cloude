package com.cloude.app.UI.files

import androidx.compose.foundation.background
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.cloude.app.Utilities.DS

@Composable
fun CSVTableViewer(text: String, delimiter: Char = ',', modifier: Modifier = Modifier) {
    val rows = remember(text, delimiter) { parseCSV(text, delimiter) }

    if (rows.isEmpty()) {
        Text(
            text = "Empty file",
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurface.copy(alpha = DS.Opacity.m),
            modifier = modifier
        )
        return
    }

    val hasHeader = rows.size > 1
    val maxCols = rows.maxOf { it.size }
    val colWidths = remember(rows) {
        (0 until maxCols).map { col ->
            val maxLen = rows.maxOf { row -> if (col < row.size) row[col].length else 0 }
            (maxLen.coerceIn(6, 40) * 8 + 16).dp
        }
    }

    Column(modifier = modifier
        .horizontalScroll(rememberScrollState())
    ) {
        if (hasHeader) {
            Row {
                rows.first().forEachIndexed { i, cell ->
                    Text(
                        text = cell,
                        style = MaterialTheme.typography.bodySmall.copy(
                            fontWeight = FontWeight.SemiBold
                        ),
                        maxLines = 1,
                        modifier = Modifier
                            .width(colWidths.getOrElse(i) { 80.dp })
                            .background(MaterialTheme.colorScheme.surfaceVariant.copy(alpha = DS.Opacity.m))
                            .padding(horizontal = DS.Spacing.s, vertical = DS.Spacing.s)
                    )
                }
            }
            HorizontalDivider(color = MaterialTheme.colorScheme.outline.copy(alpha = 0.2f))
        }

        val dataRows = if (hasHeader) rows.drop(1) else rows
        dataRows.forEachIndexed { rowIdx, row ->
            Row(
                modifier = if (rowIdx % 2 != 0)
                    Modifier.background(MaterialTheme.colorScheme.surfaceVariant.copy(alpha = DS.Opacity.s))
                else Modifier
            ) {
                row.forEachIndexed { i, cell ->
                    Text(
                        text = cell,
                        style = MaterialTheme.typography.bodySmall.copy(fontFamily = FontFamily.Monospace),
                        maxLines = 2,
                        modifier = Modifier
                            .width(colWidths.getOrElse(i) { 80.dp })
                            .padding(horizontal = DS.Spacing.s, vertical = DS.Spacing.xs)
                    )
                }
            }
        }
    }
}

private fun parseCSV(text: String, delimiter: Char): List<List<String>> {
    val rows = mutableListOf<List<String>>()
    val current = mutableListOf<String>()
    val field = StringBuilder()
    var inQuotes = false
    val chars = text.toCharArray()
    var i = 0

    while (i < chars.size) {
        val char = chars[i]
        if (inQuotes) {
            if (char == '"' && i + 1 < chars.size && chars[i + 1] == '"') {
                field.append('"')
                i += 2
            } else if (char == '"') {
                inQuotes = false
                i++
            } else {
                field.append(char)
                i++
            }
        } else {
            when (char) {
                '"' -> { inQuotes = true; i++ }
                delimiter -> {
                    current.add(field.toString().trim())
                    field.clear()
                    i++
                }
                '\n' -> {
                    current.add(field.toString().trim())
                    if (current.any { it.isNotEmpty() }) rows.add(current.toList())
                    current.clear()
                    field.clear()
                    i++
                }
                '\r' -> i++
                else -> { field.append(char); i++ }
            }
        }
    }

    if (field.isNotEmpty() || current.isNotEmpty()) {
        current.add(field.toString().trim())
        if (current.any { it.isNotEmpty() }) rows.add(current.toList())
    }

    val maxCols = rows.maxOfOrNull { it.size } ?: 0
    return rows.map { row -> row + List(maxOf(0, maxCols - row.size)) { "" } }
}

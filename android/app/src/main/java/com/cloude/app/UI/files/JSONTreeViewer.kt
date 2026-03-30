package com.cloude.app.UI.files

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.ExpandMore
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.key
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.unit.dp
import com.cloude.app.Utilities.DS
import org.json.JSONArray
import org.json.JSONObject

@Composable
fun JSONTreeViewer(text: String, modifier: Modifier = Modifier) {
    val parsed = remember(text) {
        try {
            val trimmed = text.trim()
            if (trimmed.startsWith("{")) JSONObject(trimmed)
            else if (trimmed.startsWith("[")) JSONArray(trimmed)
            else null
        } catch (_: Exception) { null }
    }

    if (parsed == null) {
        Text(
            text = "Invalid JSON",
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.error,
            modifier = modifier
        )
        return
    }

    Column(modifier = modifier.padding(DS.Spacing.m)) {
        JSONNodeView(key = null, value = parsed, depth = 0, startExpanded = true)
    }
}

@Composable
private fun JSONNodeView(key: String?, value: Any?, depth: Int, startExpanded: Boolean = false) {
    var expanded by remember { mutableStateOf(startExpanded) }
    val textStyle = MaterialTheme.typography.bodySmall.copy(fontFamily = FontFamily.Monospace)

    when (value) {
        is JSONObject -> {
            val keys = remember(value) { value.keys().asSequence().toList().sorted() }
            Row(
                verticalAlignment = Alignment.CenterVertically,
                modifier = Modifier
                    .clickable { expanded = !expanded }
                    .padding(vertical = 2.dp)
            ) {
                Icon(
                    imageVector = if (expanded) Icons.Default.ExpandMore else Icons.Default.ChevronRight,
                    contentDescription = null,
                    tint = MaterialTheme.colorScheme.onSurface.copy(alpha = DS.Opacity.m),
                    modifier = Modifier.padding(end = DS.Spacing.xs)
                )
                if (key != null && depth > 0) {
                    Text(text = "$key: ", style = textStyle, color = MaterialTheme.colorScheme.onSurface)
                }
                if (expanded) {
                    Text(text = "{", style = textStyle, color = MaterialTheme.colorScheme.onSurface.copy(alpha = DS.Opacity.m))
                } else {
                    Text(
                        text = "{ ${keys.size} item${if (keys.size == 1) "" else "s"} }",
                        style = textStyle,
                        color = MaterialTheme.colorScheme.onSurface.copy(alpha = DS.Opacity.m)
                    )
                }
            }
            if (expanded) {
                Column(modifier = Modifier.padding(start = DS.Spacing.l)) {
                    keys.forEach { k -> key(k) { JSONNodeView(key = k, value = value.opt(k), depth = depth + 1) } }
                }
                Text(
                    text = "}",
                    style = textStyle,
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = DS.Opacity.m),
                    modifier = Modifier.padding(start = DS.Spacing.s, top = 2.dp, bottom = 2.dp)
                )
            }
        }
        is JSONArray -> {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                modifier = Modifier
                    .clickable { expanded = !expanded }
                    .padding(vertical = 2.dp)
            ) {
                Icon(
                    imageVector = if (expanded) Icons.Default.ExpandMore else Icons.Default.ChevronRight,
                    contentDescription = null,
                    tint = MaterialTheme.colorScheme.onSurface.copy(alpha = DS.Opacity.m),
                    modifier = Modifier.padding(end = DS.Spacing.xs)
                )
                if (key != null && depth > 0) {
                    Text(text = "$key: ", style = textStyle, color = MaterialTheme.colorScheme.onSurface)
                }
                if (expanded) {
                    Text(text = "[", style = textStyle, color = MaterialTheme.colorScheme.onSurface.copy(alpha = DS.Opacity.m))
                } else {
                    Text(
                        text = "[ ${value.length()} item${if (value.length() == 1) "" else "s"} ]",
                        style = textStyle,
                        color = MaterialTheme.colorScheme.onSurface.copy(alpha = DS.Opacity.m)
                    )
                }
            }
            if (expanded) {
                Column(modifier = Modifier.padding(start = DS.Spacing.l)) {
                    (0 until value.length()).forEach { i -> key(i) { JSONNodeView(key = "$i", value = value.opt(i), depth = depth + 1) } }
                }
                Text(
                    text = "]",
                    style = textStyle,
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = DS.Opacity.m),
                    modifier = Modifier.padding(start = DS.Spacing.s, top = 2.dp, bottom = 2.dp)
                )
            }
        }
        is String -> LeafRow(key, depth) { Text(text = "\"$value\"", style = textStyle, color = SyntaxHighlighter.stringColor) }
        is Number -> LeafRow(key, depth) { Text(text = value.toString(), style = textStyle, color = SyntaxHighlighter.numberColor) }
        is Boolean -> LeafRow(key, depth) { Text(text = value.toString(), style = textStyle, color = SyntaxHighlighter.keywordColor) }
        else -> LeafRow(key, depth) { Text(text = "null", style = textStyle, color = MaterialTheme.colorScheme.onSurface.copy(alpha = DS.Opacity.m)) }
    }
}

@Composable
private fun LeafRow(key: String?, depth: Int, content: @Composable () -> Unit) {
    val textStyle = MaterialTheme.typography.bodySmall.copy(fontFamily = FontFamily.Monospace)
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier.padding(vertical = 2.dp, horizontal = DS.Spacing.xs)
    ) {
        if (key != null && depth > 0) {
            Text(text = "$key: ", style = textStyle, color = MaterialTheme.colorScheme.onSurface)
        }
        content()
    }
}

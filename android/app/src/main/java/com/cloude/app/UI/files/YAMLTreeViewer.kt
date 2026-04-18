package com.cloude.app.UI.files

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import org.json.JSONArray
import org.json.JSONObject

@Composable
fun YAMLTreeViewer(text: String, modifier: Modifier = Modifier) {
    val jsonText = remember(text) {
        val parsed = YAMLParser.parse(text) ?: return@remember null
        when (val json = toJSON(parsed)) {
            is JSONObject -> json.toString(2)
            is JSONArray -> json.toString(2)
            else -> null
        }
    }

    if (jsonText == null) {
        Text(
            text = "Invalid YAML",
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.error,
            modifier = modifier
        )
        return
    }

    JSONTreeViewer(text = jsonText, modifier = modifier)
}

private fun toJSON(value: Any?): Any? = when (value) {
    is Map<*, *> -> JSONObject().apply {
        value.forEach { (k, v) -> put(k.toString(), toJSON(v) ?: JSONObject.NULL) }
    }
    is List<*> -> JSONArray().apply {
        value.forEach { put(toJSON(it) ?: JSONObject.NULL) }
    }
    is Boolean -> value
    is Number -> value
    is String -> value
    null -> JSONObject.NULL
    else -> value.toString()
}

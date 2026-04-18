package com.cloude.app.UI.files

import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.viewinterop.AndroidView
import com.cloude.app.Utilities.Accent
import com.cloude.app.Utilities.DS

@Composable
fun HtmlPreview(data: ByteArray, modifier: Modifier = Modifier) {
    val htmlString = remember(data) { String(data, Charsets.UTF_8) }
    var showSource by remember { mutableStateOf(false) }

    Column(modifier = modifier) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = DS.Spacing.m, vertical = DS.Spacing.s),
            horizontalArrangement = Arrangement.spacedBy(DS.Spacing.s)
        ) {
            ToggleChip(label = "Rendered", isSelected = !showSource, onClick = { showSource = false })
            ToggleChip(label = "Source", isSelected = showSource, onClick = { showSource = true })
        }

        if (showSource) {
            Text(
                text = htmlString,
                style = MaterialTheme.typography.bodySmall.copy(
                    fontFamily = FontFamily.Monospace,
                    lineHeight = 18.sp
                ),
                color = MaterialTheme.colorScheme.onSurface,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(DS.Spacing.m)
                    .horizontalScroll(rememberScrollState())
            )
        } else {
            AndroidView(
                factory = { context ->
                    WebView(context).apply {
                        webViewClient = WebViewClient()
                        settings.javaScriptEnabled = false
                        settings.allowFileAccess = false
                        settings.allowContentAccess = false
                        setBackgroundColor(android.graphics.Color.WHITE)
                        loadDataWithBaseURL(null, htmlString, "text/html", "UTF-8", null)
                    }
                },
                modifier = Modifier
                    .fillMaxWidth()
                    .heightIn(min = 200.dp, max = 600.dp)
            )
        }
    }
}

@Composable
private fun ToggleChip(label: String, isSelected: Boolean, onClick: () -> Unit) {
    Text(
        text = label,
        style = MaterialTheme.typography.labelSmall,
        color = if (isSelected) Accent else MaterialTheme.colorScheme.onSurface.copy(alpha = DS.Opacity.m),
        modifier = Modifier
            .clip(RoundedCornerShape(DS.Radius.m))
            .background(if (isSelected) Accent.copy(alpha = 0.15f) else MaterialTheme.colorScheme.surfaceVariant)
            .clickable(onClick = onClick)
            .padding(horizontal = DS.Spacing.m, vertical = DS.Spacing.xs)
    )
}

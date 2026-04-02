package com.cloude.app.UI.files

import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView

@Composable
fun SvgPreview(data: ByteArray, modifier: Modifier = Modifier) {
    val svgString = remember(data) { String(data, Charsets.UTF_8) }
    val html = remember(svgString) {
        """
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <style>
                body { margin: 0; padding: 16px; background: transparent; display: flex; justify-content: center; align-items: center; }
                svg { max-width: 100%; height: auto; }
            </style>
        </head>
        <body>$svgString</body>
        </html>
        """.trimIndent()
    }

    AndroidView(
        factory = { context ->
            WebView(context).apply {
                webViewClient = WebViewClient()
                settings.javaScriptEnabled = false
                setBackgroundColor(android.graphics.Color.TRANSPARENT)
                loadDataWithBaseURL(null, html, "text/html", "UTF-8", null)
            }
        },
        modifier = modifier
            .fillMaxWidth()
            .heightIn(min = 200.dp, max = 500.dp)
    )
}

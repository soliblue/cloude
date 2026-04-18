package com.cloude.app.UI.files

import android.graphics.BitmapFactory
import android.graphics.ImageDecoder
import android.graphics.drawable.AnimatedImageDrawable
import android.os.Build
import android.widget.ImageView
import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.viewinterop.AndroidView
import java.nio.ByteBuffer

@Composable
fun GifPreview(data: ByteArray, modifier: Modifier = Modifier) {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
        AndroidView(
            factory = { context ->
                ImageView(context).apply {
                    scaleType = ImageView.ScaleType.FIT_CENTER
                    adjustViewBounds = true
                    val source = ImageDecoder.createSource(ByteBuffer.wrap(data))
                    val drawable = ImageDecoder.decodeDrawable(source)
                    setImageDrawable(drawable)
                    if (drawable is AnimatedImageDrawable) drawable.start()
                }
            },
            modifier = modifier.fillMaxWidth()
        )
    } else {
        val bitmap = remember(data) { BitmapFactory.decodeByteArray(data, 0, data.size) }
        if (bitmap != null) {
            Image(
                bitmap = bitmap.asImageBitmap(),
                contentDescription = "GIF (static)",
                contentScale = ContentScale.Fit,
                modifier = modifier.fillMaxWidth()
            )
        }
    }
}

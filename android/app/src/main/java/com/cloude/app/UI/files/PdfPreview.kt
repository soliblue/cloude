package com.cloude.app.UI.files

import android.graphics.Bitmap
import android.graphics.pdf.PdfRenderer
import android.os.ParcelFileDescriptor
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import com.cloude.app.Utilities.DS
import java.io.File

@Composable
fun PdfPreview(data: ByteArray, modifier: Modifier = Modifier) {
    val context = LocalContext.current
    val pdfState = remember(data) {
        val tempFile = File(context.cacheDir, "pdf_preview_${System.currentTimeMillis()}.pdf")
        tempFile.writeBytes(data)
        val fd = ParcelFileDescriptor.open(tempFile, ParcelFileDescriptor.MODE_READ_ONLY)
        val renderer = PdfRenderer(fd)
        PdfState(renderer, fd, tempFile)
    }

    DisposableEffect(pdfState) {
        onDispose {
            pdfState.renderer.close()
            pdfState.fd.close()
            pdfState.tempFile.delete()
        }
    }

    val pageCount = pdfState.renderer.pageCount
    val bitmaps = remember(pdfState) {
        (0 until pageCount).map { i ->
            val page = pdfState.renderer.openPage(i)
            val scale = 2
            val bitmap = Bitmap.createBitmap(
                page.width * scale, page.height * scale, Bitmap.Config.ARGB_8888
            )
            bitmap.eraseColor(android.graphics.Color.WHITE)
            page.render(bitmap, null, null, PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY)
            page.close()
            bitmap
        }
    }

    LazyColumn(
        modifier = modifier,
        verticalArrangement = Arrangement.spacedBy(DS.Spacing.s)
    ) {
        itemsIndexed(bitmaps) { index, bitmap ->
            Box(modifier = Modifier.fillMaxWidth()) {
                Image(
                    bitmap = bitmap.asImageBitmap(),
                    contentDescription = "Page ${index + 1}",
                    contentScale = ContentScale.FillWidth,
                    modifier = Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(DS.Radius.s))
                )
                Text(
                    text = "${index + 1} / $pageCount",
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f),
                    modifier = Modifier
                        .align(Alignment.BottomEnd)
                        .padding(DS.Spacing.s)
                        .background(
                            MaterialTheme.colorScheme.surface.copy(alpha = 0.7f),
                            RoundedCornerShape(DS.Radius.s)
                        )
                        .padding(horizontal = DS.Spacing.s, vertical = DS.Spacing.xs)
                )
            }
        }
    }
}

private data class PdfState(
    val renderer: PdfRenderer,
    val fd: ParcelFileDescriptor,
    val tempFile: File
)

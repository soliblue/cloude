package com.cloude.app.UI.files

import android.media.MediaPlayer
import android.net.Uri
import android.widget.VideoView
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.size
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.GraphicEq
import androidx.compose.material.icons.filled.PauseCircle
import androidx.compose.material.icons.filled.PlayCircle
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.viewinterop.AndroidView
import com.cloude.app.Utilities.Accent
import com.cloude.app.Utilities.DS
import kotlinx.coroutines.delay
import java.io.File

@Composable
fun AudioPreview(data: ByteArray, fileName: String, modifier: Modifier = Modifier) {
    val context = LocalContext.current
    var isPlaying by remember { mutableStateOf(false) }
    var progress by remember { mutableFloatStateOf(0f) }
    var durationMs by remember { mutableStateOf(0) }
    var currentMs by remember { mutableStateOf(0) }

    val player = remember {
        val tempFile = File(context.cacheDir, "audio_preview_${System.currentTimeMillis()}")
        tempFile.writeBytes(data)
        MediaPlayer().apply {
            setDataSource(tempFile.absolutePath)
            prepare()
        }
    }

    LaunchedEffect(player) {
        durationMs = player.duration
    }

    LaunchedEffect(isPlaying) {
        while (isPlaying) {
            currentMs = player.currentPosition
            progress = if (durationMs > 0) currentMs.toFloat() / durationMs else 0f
            if (!player.isPlaying) {
                isPlaying = false
                progress = 0f
                currentMs = 0
                player.seekTo(0)
            }
            delay(50)
        }
    }

    DisposableEffect(Unit) {
        onDispose {
            player.release()
        }
    }

    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        modifier = modifier.fillMaxWidth()
    ) {
        Spacer(modifier = Modifier.height(DS.Spacing.xl))

        Icon(
            imageVector = Icons.Default.GraphicEq,
            contentDescription = null,
            tint = Accent,
            modifier = Modifier.size(DS.Size.l)
        )

        Spacer(modifier = Modifier.height(DS.Spacing.l))

        Text(
            text = fileName,
            style = MaterialTheme.typography.titleSmall,
            color = MaterialTheme.colorScheme.onSurface
        )

        Spacer(modifier = Modifier.height(DS.Spacing.l))

        LinearProgressIndicator(
            progress = { progress },
            modifier = Modifier.fillMaxWidth(0.7f),
            color = Accent,
            trackColor = MaterialTheme.colorScheme.onSurface.copy(alpha = DS.Opacity.s)
        )

        Spacer(modifier = Modifier.height(DS.Spacing.s))

        Row(modifier = Modifier.fillMaxWidth(0.7f)) {
            Text(
                text = formatTime(currentMs),
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = DS.Opacity.m)
            )
            Spacer(modifier = Modifier.weight(1f))
            Text(
                text = formatTime(durationMs),
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = DS.Opacity.m)
            )
        }

        Spacer(modifier = Modifier.height(DS.Spacing.m))

        IconButton(onClick = {
            if (isPlaying) {
                player.pause()
                isPlaying = false
            } else {
                player.start()
                isPlaying = true
            }
        }) {
            Icon(
                imageVector = if (isPlaying) Icons.Default.PauseCircle else Icons.Default.PlayCircle,
                contentDescription = if (isPlaying) "Pause" else "Play",
                tint = Accent,
                modifier = Modifier.size(DS.Size.l)
            )
        }

        Spacer(modifier = Modifier.height(DS.Spacing.xl))
    }
}

@Composable
fun VideoPreview(data: ByteArray, fileName: String, modifier: Modifier = Modifier) {
    val context = LocalContext.current

    val tempFile = remember {
        val ext = fileName.substringAfterLast('.', "mp4")
        val file = File(context.cacheDir, "video_preview_${System.currentTimeMillis()}.$ext")
        file.writeBytes(data)
        file
    }

    DisposableEffect(Unit) {
        onDispose {
            tempFile.delete()
        }
    }

    Box(
        contentAlignment = Alignment.Center,
        modifier = modifier.fillMaxWidth()
    ) {
        AndroidView(
            factory = { ctx ->
                VideoView(ctx).apply {
                    setVideoURI(Uri.fromFile(tempFile))
                    setOnPreparedListener { mp ->
                        mp.isLooping = false
                        start()
                    }
                }
            },
            modifier = Modifier
                .fillMaxWidth()
                .aspectRatio(16f / 9f)
        )
    }
}

private fun formatTime(ms: Int): String {
    val totalSec = ms / 1000
    val min = totalSec / 60
    val sec = totalSec % 60
    return "%d:%02d".format(min, sec)
}

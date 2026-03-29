package com.cloude.app.UI.chat

import android.Manifest
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import android.util.Base64
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.Send
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Image
import androidx.compose.material.icons.filled.Mic
import androidx.compose.material.icons.filled.Stop
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.unit.dp
import androidx.core.content.ContextCompat
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.rememberScrollState
import com.cloude.app.Models.Skill
import com.cloude.app.Models.SlashCommand
import com.cloude.app.Services.AudioRecorder
import com.cloude.app.Utilities.Accent
import com.cloude.app.Utilities.DS
import com.cloude.app.Utilities.PastelRed
import java.io.ByteArrayOutputStream

@Composable
fun InputBar(
    isRunning: Boolean,
    isTranscribing: Boolean = false,
    whisperReady: Boolean = false,
    pendingTranscription: String? = null,
    currentEffort: String?,
    currentModel: String?,
    skills: List<Skill> = emptyList(),
    onSend: (String, List<String>?) -> Unit,
    onAbort: () -> Unit,
    onTranscribe: (String) -> Unit = {},
    onTranscriptionConsumed: () -> Unit = {},
    onEffortChange: (String?) -> Unit,
    onModelChange: (String?) -> Unit,
    modifier: Modifier = Modifier
) {
    var text by remember { mutableStateOf("") }
    var attachedImages by remember { mutableStateOf<List<Pair<Bitmap, String>>>(emptyList()) }
    var expandedImage by remember { mutableStateOf<Bitmap?>(null) }
    val context = LocalContext.current

    val recorder = remember { AudioRecorder() }
    val isRecording by recorder.isRecording.collectAsState()
    val audioLevel by recorder.audioLevel.collectAsState()

    DisposableEffect(Unit) { onDispose { recorder.release() } }

    val permissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { granted ->
        if (granted) recorder.startRecording()
    }

    fun startRecordingWithPermission() {
        if (ContextCompat.checkSelfPermission(context, Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED) {
            recorder.startRecording()
        } else {
            permissionLauncher.launch(Manifest.permission.RECORD_AUDIO)
        }
    }

    fun stopRecordingAndTranscribe() {
        val base64 = recorder.stopRecording() ?: return
        onTranscribe(base64)
    }

    LaunchedEffect(pendingTranscription) {
        if (pendingTranscription != null) {
            text = if (text.isEmpty()) pendingTranscription else "$text $pendingTranscription"
            onTranscriptionConsumed()
        }
    }

    val imagePicker = rememberLauncherForActivityResult(
        ActivityResultContracts.PickMultipleVisualMedia(maxItems = 5)
    ) { uris: List<Uri> ->
        val newImages = uris.mapNotNull { uri ->
            context.contentResolver.openInputStream(uri)?.use { stream ->
                val bitmap = BitmapFactory.decodeStream(stream) ?: return@use null
                val scaled = scaleBitmap(bitmap, 1920)
                val base64 = bitmapToBase64(scaled)
                scaled to base64
            }
        }
        attachedImages = attachedImages + newImages
    }

    fun doSend() {
        if (text.isNotBlank() || attachedImages.isNotEmpty()) {
            val images = attachedImages.map { it.second }.takeIf { it.isNotEmpty() }
            onSend(text, images)
            text = ""
            attachedImages = emptyList()
        }
    }

    val slashQuery = remember(text) {
        if (text.startsWith("/")) text.drop(1).takeWhile { it != ' ' && it != '\n' }
        else null
    }
    val suggestions = remember(slashQuery, skills) {
        if (slashQuery != null) SlashCommand.filtered(slashQuery, skills) else emptyList()
    }

    Column(modifier = modifier) {
        if (suggestions.isNotEmpty() && !isRunning) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .horizontalScroll(rememberScrollState())
                    .padding(bottom = DS.Spacing.xs),
                horizontalArrangement = Arrangement.spacedBy(DS.Spacing.xs)
            ) {
                suggestions.take(10).forEach { command ->
                    SlashCommandPill(
                        command = command,
                        onSelect = {
                            val resolved = command.resolvesTo ?: command.name
                            text = "/$resolved"
                            if (!command.hasParameters) {
                                val images = attachedImages.map { it.second }.takeIf { it.isNotEmpty() }
                                onSend(text, images)
                                text = ""
                                attachedImages = emptyList()
                            } else {
                                text = "/$resolved "
                            }
                        }
                    )
                }
            }
        }

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

        if (attachedImages.isNotEmpty()) {
            Row(
                modifier = Modifier.padding(bottom = DS.Spacing.s),
                horizontalArrangement = Arrangement.spacedBy(DS.Spacing.s)
            ) {
                attachedImages.forEachIndexed { index, (bitmap, _) ->
                    Box {
                        Image(
                            bitmap = bitmap.asImageBitmap(),
                            contentDescription = "Attached image",
                            modifier = Modifier
                                .size(80.dp)
                                .clip(RoundedCornerShape(DS.Radius.m))
                                .border(1.dp, MaterialTheme.colorScheme.outline.copy(alpha = 0.3f), RoundedCornerShape(DS.Radius.m))
                                .clickable { expandedImage = bitmap },
                            contentScale = ContentScale.Crop
                        )
                        Icon(
                            imageVector = Icons.Default.Close,
                            contentDescription = "Remove",
                            tint = MaterialTheme.colorScheme.onPrimary,
                            modifier = Modifier
                                .size(DS.Icon.m)
                                .align(Alignment.TopEnd)
                                .clip(CircleShape)
                                .background(MaterialTheme.colorScheme.error)
                                .clickable {
                                    attachedImages = attachedImages.toMutableList().apply { removeAt(index) }
                                }
                        )
                    }
                }
            }
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
            IconButton(
                onClick = { imagePicker.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly)) },
                modifier = Modifier.size(DS.Size.m),
                enabled = !isRecording
            ) {
                Icon(
                    imageVector = Icons.Default.Image,
                    contentDescription = "Attach image",
                    tint = if (isRecording) MaterialTheme.colorScheme.onSurface.copy(alpha = DS.Opacity.s)
                           else Accent,
                    modifier = Modifier.size(DS.Icon.m)
                )
            }

            if (isRecording) {
                RecordingIndicator(
                    audioLevel = audioLevel,
                    modifier = Modifier
                        .weight(1f)
                        .padding(vertical = DS.Spacing.xs)
                )
            } else if (isTranscribing) {
                Row(
                    modifier = Modifier
                        .weight(1f)
                        .padding(vertical = DS.Spacing.xs),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(DS.Spacing.s)
                ) {
                    CircularProgressIndicator(
                        modifier = Modifier.size(DS.Icon.s),
                        strokeWidth = 2.dp,
                        color = Accent
                    )
                    Text(
                        text = "Transcribing...",
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurface.copy(alpha = DS.Opacity.m)
                    )
                }
            } else {
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
                        if (!isRunning) doSend()
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
            }

            if (isRunning) {
                IconButton(onClick = onAbort) {
                    Icon(
                        imageVector = Icons.Default.Stop,
                        contentDescription = "Stop",
                        tint = PastelRed
                    )
                }
            } else if (isRecording) {
                IconButton(onClick = { stopRecordingAndTranscribe() }) {
                    Icon(
                        imageVector = Icons.Default.Stop,
                        contentDescription = "Stop recording",
                        tint = PastelRed
                    )
                }
            } else if (text.isEmpty() && attachedImages.isEmpty() && whisperReady && !isTranscribing) {
                IconButton(onClick = { startRecordingWithPermission() }) {
                    Icon(
                        imageVector = Icons.Default.Mic,
                        contentDescription = "Record voice",
                        tint = Accent
                    )
                }
            } else {
                IconButton(
                    onClick = { doSend() },
                    enabled = text.isNotBlank() || attachedImages.isNotEmpty()
                ) {
                    Icon(
                        imageVector = Icons.AutoMirrored.Filled.Send,
                        contentDescription = "Send",
                        tint = if (text.isNotBlank() || attachedImages.isNotEmpty()) Accent
                               else MaterialTheme.colorScheme.onSurface.copy(alpha = DS.Opacity.s)
                    )
                }
            }
        }
    }

    expandedImage?.let { bitmap ->
        ImagePreviewSheet(bitmap = bitmap, onDismiss = { expandedImage = null })
    }
}

@Composable
private fun RecordingIndicator(audioLevel: Float, modifier: Modifier = Modifier) {
    val infiniteTransition = rememberInfiniteTransition(label = "recording")
    val pulseAlpha by infiniteTransition.animateFloat(
        initialValue = 0.4f,
        targetValue = 1f,
        animationSpec = infiniteRepeatable(
            animation = tween(600),
            repeatMode = RepeatMode.Reverse
        ),
        label = "pulse"
    )

    Row(
        modifier = modifier,
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(DS.Spacing.s)
    ) {
        Box(
            modifier = Modifier
                .size(DS.Spacing.m)
                .clip(CircleShape)
                .background(PastelRed.copy(alpha = pulseAlpha))
        )
        Text(
            text = "Recording...",
            style = MaterialTheme.typography.bodyMedium,
            color = PastelRed
        )
        Row(
            horizontalArrangement = Arrangement.spacedBy(2.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            repeat(5) { i ->
                val threshold = i * 0.2f
                val barHeight = if (audioLevel > threshold) 8.dp + (12.dp * audioLevel) else 4.dp
                Box(
                    modifier = Modifier
                        .width(3.dp)
                        .height(barHeight)
                        .clip(RoundedCornerShape(1.5.dp))
                        .background(PastelRed.copy(alpha = 0.7f))
                )
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun ImagePreviewSheet(bitmap: Bitmap, onDismiss: () -> Unit) {
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
        containerColor = MaterialTheme.colorScheme.surfaceVariant
    ) {
        Image(
            bitmap = bitmap.asImageBitmap(),
            contentDescription = "Image preview",
            modifier = Modifier
                .fillMaxWidth()
                .heightIn(max = 500.dp)
                .padding(DS.Spacing.m)
                .clip(RoundedCornerShape(DS.Radius.m)),
            contentScale = ContentScale.Fit
        )
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

private fun scaleBitmap(bitmap: Bitmap, maxDimension: Int): Bitmap {
    val ratio = minOf(maxDimension.toFloat() / bitmap.width, maxDimension.toFloat() / bitmap.height)
    if (ratio >= 1f) return bitmap
    return Bitmap.createScaledBitmap(
        bitmap,
        (bitmap.width * ratio).toInt(),
        (bitmap.height * ratio).toInt(),
        true
    )
}

private fun bitmapToBase64(bitmap: Bitmap): String {
    val stream = ByteArrayOutputStream()
    bitmap.compress(Bitmap.CompressFormat.JPEG, 85, stream)
    return Base64.encodeToString(stream.toByteArray(), Base64.NO_WRAP)
}

@Composable
private fun SlashCommandPill(command: SlashCommand, onSelect: () -> Unit) {
    Row(
        modifier = Modifier
            .clip(RoundedCornerShape(DS.Radius.m))
            .background(
                if (command.isSkill) Accent.copy(alpha = DS.Opacity.s)
                else MaterialTheme.colorScheme.surfaceVariant
            )
            .clickable(onClick = onSelect)
            .padding(horizontal = DS.Spacing.m, vertical = DS.Spacing.xs),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(DS.Spacing.xs)
    ) {
        Text(
            text = "/${command.name}",
            style = MaterialTheme.typography.labelSmall,
            color = if (command.isSkill) Accent else MaterialTheme.colorScheme.onSurface
        )
        if (command.description.isNotEmpty()) {
            Text(
                text = command.description,
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = DS.Opacity.m),
                maxLines = 1,
                overflow = androidx.compose.ui.text.style.TextOverflow.Ellipsis,
                modifier = Modifier.widthIn(max = 150.dp)
            )
        }
    }
}

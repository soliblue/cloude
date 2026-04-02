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
import androidx.compose.material.icons.filled.CameraAlt
import androidx.core.content.FileProvider
import java.io.File
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.togetherWith
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
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.input.pointer.positionChange
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.Send
import androidx.compose.material.icons.filled.AttachFile
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Description
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
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.platform.LocalSoftwareKeyboardController
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.unit.dp
import androidx.core.content.ContextCompat
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.rememberScrollState
import com.cloude.app.Models.AttachedFilePayload
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
    fileSearchResults: List<String> = emptyList(),
    workingDirectory: String? = null,
    initialDraft: String = "",
    onDraftChange: (String) -> Unit = {},
    onSend: (String, List<String>?, List<AttachedFilePayload>?) -> Unit,
    onAbort: () -> Unit,
    onTranscribe: (String) -> Unit = {},
    onTranscriptionConsumed: () -> Unit = {},
    onEffortChange: (String?) -> Unit,
    onModelChange: (String?) -> Unit,
    onFileSearch: (String) -> Unit = {},
    onFileSearchClear: () -> Unit = {},
    modifier: Modifier = Modifier
) {
    var text by remember { mutableStateOf(initialDraft) }
    var attachedImages by remember { mutableStateOf<List<Pair<Bitmap, String>>>(emptyList()) }
    var attachedFiles by remember { mutableStateOf<List<AttachedFilePayload>>(emptyList()) }
    var expandedImage by remember { mutableStateOf<Bitmap?>(null) }
    val context = LocalContext.current
    val keyboardController = LocalSoftwareKeyboardController.current

    var isFocused by remember { mutableStateOf(false) }
    var dragCancelled by remember { mutableStateOf(false) }
    val recentHistory = remember { mutableListOf<String>() }

    val recorder = remember { AudioRecorder() }
    val isRecording by recorder.isRecording.collectAsState()
    val audioLevel by recorder.audioLevel.collectAsState()

    LaunchedEffect(text) { onDraftChange(text) }

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

    val filePicker = rememberLauncherForActivityResult(
        ActivityResultContracts.OpenMultipleDocuments()
    ) { uris: List<Uri> ->
        val newFiles = uris.mapNotNull { uri ->
            context.contentResolver.openInputStream(uri)?.use { stream ->
                val bytes = stream.readBytes()
                val name = uri.lastPathSegment?.substringAfterLast('/') ?: "file"
                AttachedFilePayload(
                    name = name,
                    data = Base64.encodeToString(bytes, Base64.NO_WRAP)
                )
            }
        }
        attachedFiles = attachedFiles + newFiles
    }

    var cameraUri by remember { mutableStateOf<Uri?>(null) }
    val cameraLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.TakePicture()
    ) { success ->
        if (success) {
            cameraUri?.let { uri ->
                context.contentResolver.openInputStream(uri)?.use { stream ->
                    val bitmap = BitmapFactory.decodeStream(stream) ?: return@use
                    val scaled = scaleBitmap(bitmap, 1920)
                    val base64 = bitmapToBase64(scaled)
                    attachedImages = attachedImages + (scaled to base64)
                }
            }
        }
    }
    val cameraPermissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { granted ->
        if (granted) {
            val photoFile = File(context.cacheDir, "camera_photos").apply { mkdirs() }.let {
                File(it, "photo_${System.currentTimeMillis()}.jpg")
            }
            val uri = FileProvider.getUriForFile(context, "com.cloude.app.fileprovider", photoFile)
            cameraUri = uri
            cameraLauncher.launch(uri)
        }
    }

    fun launchCamera() {
        if (ContextCompat.checkSelfPermission(context, Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED) {
            val photoFile = File(context.cacheDir, "camera_photos").apply { mkdirs() }.let {
                File(it, "photo_${System.currentTimeMillis()}.jpg")
            }
            val uri = FileProvider.getUriForFile(context, "com.cloude.app.fileprovider", photoFile)
            cameraUri = uri
            cameraLauncher.launch(uri)
        } else {
            cameraPermissionLauncher.launch(Manifest.permission.CAMERA)
        }
    }

    fun doSend() {
        if (text.isNotBlank() || attachedImages.isNotEmpty() || attachedFiles.isNotEmpty()) {
            val trimmed = text.trim()
            if (trimmed.isNotBlank() && !trimmed.startsWith("/") && trimmed.length <= 100) {
                recentHistory.remove(trimmed)
                recentHistory.add(0, trimmed)
                if (recentHistory.size > 20) recentHistory.removeLast()
            }
            val images = attachedImages.map { it.second }.takeIf { it.isNotEmpty() }
            val files = attachedFiles.takeIf { it.isNotEmpty() }
            onSend(text, images, files)
            text = ""
            attachedImages = emptyList()
            attachedFiles = emptyList()
            keyboardController?.hide()
        }
    }

    val tips = remember { listOf(
        "Ask anything...",
        "Try /compact to save context",
        "Attach images with the gallery button",
        "Use /plans to view your roadmap",
        "Try /skills to browse available skills",
        "Take a photo with the camera button",
        "Use /usage to check token stats",
        "Attach files with the paperclip",
        "Long-press messages to copy or fork",
        "Swipe between windows with tabs"
    ) }
    var tipIndex by remember { mutableIntStateOf(0) }
    LaunchedEffect(Unit) {
        while (true) {
            kotlinx.coroutines.delay(8000)
            tipIndex = (tipIndex + 1) % tips.size
        }
    }

    val slashQuery = remember(text) {
        if (text.startsWith("/")) text.drop(1).takeWhile { it != ' ' && it != '\n' }
        else null
    }
    val suggestions = remember(slashQuery, skills) {
        if (slashQuery != null) SlashCommand.filtered(slashQuery, skills) else emptyList()
    }

    val atQuery = remember(text) {
        val lastAt = text.lastIndexOf('@')
        if (lastAt < 0) return@remember null
        val before = text.getOrNull(lastAt - 1)
        if (before != null && !before.isWhitespace()) return@remember null
        val after = text.substring(lastAt + 1)
        if (after.contains(' ') || after.contains('\n')) return@remember null
        after.takeIf { it.isNotEmpty() }
    }

    LaunchedEffect(atQuery) {
        if (atQuery != null) {
            kotlinx.coroutines.delay(300)
            onFileSearch(atQuery)
        } else {
            onFileSearchClear()
        }
    }

    Column(modifier = modifier) {
        if (isFocused && text.isEmpty() && recentHistory.isNotEmpty() && !isRunning) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .horizontalScroll(rememberScrollState())
                    .padding(bottom = DS.Spacing.xs),
                horizontalArrangement = Arrangement.spacedBy(DS.Spacing.xs)
            ) {
                recentHistory.take(10).forEach { entry ->
                    Text(
                        text = entry,
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.onSurface.copy(alpha = DS.Opacity.m),
                        maxLines = 1,
                        modifier = Modifier
                            .clip(RoundedCornerShape(DS.Radius.m))
                            .background(MaterialTheme.colorScheme.surfaceVariant)
                            .clickable { text = entry }
                            .padding(horizontal = DS.Spacing.m, vertical = DS.Spacing.xs)
                    )
                }
            }
        }

        if (atQuery != null && fileSearchResults.isNotEmpty() && !isRunning) {
            val wdPrefix = workingDirectory?.let { if (it.endsWith("/")) it else "$it/" } ?: ""
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .horizontalScroll(rememberScrollState())
                    .padding(bottom = DS.Spacing.xs),
                horizontalArrangement = Arrangement.spacedBy(DS.Spacing.xs)
            ) {
                fileSearchResults.take(10).forEach { path ->
                    val relativePath = if (wdPrefix.isNotEmpty() && path.startsWith(wdPrefix))
                        path.removePrefix(wdPrefix) else path.substringAfterLast('/')
                    Text(
                        text = relativePath,
                        style = MaterialTheme.typography.labelSmall.copy(
                            fontFamily = androidx.compose.ui.text.font.FontFamily.Monospace
                        ),
                        color = Accent,
                        maxLines = 1,
                        modifier = Modifier
                            .clip(RoundedCornerShape(DS.Radius.m))
                            .background(Accent.copy(alpha = 0.1f))
                            .clickable {
                                val lastAt = text.lastIndexOf('@')
                                text = if (lastAt >= 0) text.substring(0, lastAt) + path + " "
                                       else text + path + " "
                                onFileSearchClear()
                            }
                            .padding(horizontal = DS.Spacing.m, vertical = DS.Spacing.xs)
                    )
                }
            }
        }

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
                                val files = attachedFiles.takeIf { it.isNotEmpty() }
                                onSend(text, images, files)
                                text = ""
                                attachedImages = emptyList()
                                attachedFiles = emptyList()
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

        if (attachedFiles.isNotEmpty()) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .horizontalScroll(rememberScrollState())
                    .padding(bottom = DS.Spacing.s),
                horizontalArrangement = Arrangement.spacedBy(DS.Spacing.s)
            ) {
                attachedFiles.forEachIndexed { index, file ->
                    FileAttachmentPill(
                        name = file.name,
                        onRemove = {
                            attachedFiles = attachedFiles.toMutableList().apply { removeAt(index) }
                        }
                    )
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

            IconButton(
                onClick = { launchCamera() },
                modifier = Modifier.size(DS.Size.m),
                enabled = !isRecording
            ) {
                Icon(
                    imageVector = Icons.Default.CameraAlt,
                    contentDescription = "Take photo",
                    tint = if (isRecording) MaterialTheme.colorScheme.onSurface.copy(alpha = DS.Opacity.s)
                           else Accent,
                    modifier = Modifier.size(DS.Icon.m)
                )
            }

            IconButton(
                onClick = { filePicker.launch(arrayOf("*/*")) },
                modifier = Modifier.size(DS.Size.m),
                enabled = !isRecording
            ) {
                Icon(
                    imageVector = Icons.Default.AttachFile,
                    contentDescription = "Attach file",
                    tint = if (isRecording) MaterialTheme.colorScheme.onSurface.copy(alpha = DS.Opacity.s)
                           else Accent,
                    modifier = Modifier.size(DS.Icon.m)
                )
            }

            if (isRecording) {
                RecordingIndicator(
                    audioLevel = audioLevel,
                    isCancelling = dragCancelled,
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
                        .padding(vertical = DS.Spacing.xs)
                        .onFocusChanged { isFocused = it.isFocused },
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
                            AnimatedContent(
                                targetState = tipIndex,
                                transitionSpec = { fadeIn(tween(400)) togetherWith fadeOut(tween(400)) },
                                label = "tip"
                            ) { idx ->
                                Text(
                                    text = tips[idx],
                                    style = MaterialTheme.typography.bodyMedium,
                                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.4f)
                                )
                            }
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
            } else if (text.isEmpty() && attachedImages.isEmpty() && attachedFiles.isEmpty() && whisperReady && !isTranscribing) {
                Box(
                    modifier = Modifier
                        .size(48.dp)
                        .scale(if (isRecording) 1.3f else 1f)
                        .pointerInput(Unit) {
                            awaitEachGesture {
                                val down = awaitFirstDown(requireUnconsumed = false)
                                dragCancelled = false
                                startRecordingWithPermission()
                                var totalDragX = 0f
                                while (true) {
                                    val event = awaitPointerEvent()
                                    val change = event.changes.firstOrNull() ?: break
                                    if (!change.pressed) {
                                        if (dragCancelled) {
                                            recorder.cancelRecording()
                                        } else {
                                            stopRecordingAndTranscribe()
                                        }
                                        break
                                    }
                                    totalDragX += change.positionChange().x
                                    if (totalDragX < -160f && !dragCancelled) {
                                        dragCancelled = true
                                    }
                                    change.consume()
                                }
                            }
                        },
                    contentAlignment = Alignment.Center
                ) {
                    Icon(
                        imageVector = if (isRecording && dragCancelled) Icons.Default.Close
                                     else if (isRecording) Icons.Default.Mic
                                     else Icons.Default.Mic,
                        contentDescription = if (isRecording) "Release to send, drag left to cancel" else "Hold to record",
                        tint = if (isRecording && dragCancelled) PastelRed
                               else if (isRecording) PastelRed
                               else Accent,
                        modifier = Modifier.size(24.dp)
                    )
                }
            } else {
                IconButton(
                    onClick = { doSend() },
                    enabled = text.isNotBlank() || attachedImages.isNotEmpty() || attachedFiles.isNotEmpty()
                ) {
                    Icon(
                        imageVector = Icons.AutoMirrored.Filled.Send,
                        contentDescription = "Send",
                        tint = if (text.isNotBlank() || attachedImages.isNotEmpty() || attachedFiles.isNotEmpty()) Accent
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
private fun RecordingIndicator(audioLevel: Float, isCancelling: Boolean = false, modifier: Modifier = Modifier) {
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
            text = if (isCancelling) "Release to cancel" else "Recording... slide left to cancel",
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
private fun FileAttachmentPill(name: String, onRemove: () -> Unit) {
    Row(
        modifier = Modifier
            .clip(RoundedCornerShape(DS.Radius.m))
            .background(Accent.copy(alpha = 0.1f))
            .border(1.dp, Accent.copy(alpha = 0.3f), RoundedCornerShape(DS.Radius.m))
            .padding(start = DS.Spacing.s, end = DS.Spacing.xs, top = DS.Spacing.xs, bottom = DS.Spacing.xs),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(DS.Spacing.xs)
    ) {
        Icon(
            imageVector = Icons.Default.Description,
            contentDescription = null,
            tint = Accent,
            modifier = Modifier.size(DS.Icon.s)
        )
        Text(
            text = name,
            style = MaterialTheme.typography.labelSmall,
            color = Accent,
            maxLines = 1,
            overflow = androidx.compose.ui.text.style.TextOverflow.Ellipsis,
            modifier = Modifier.widthIn(max = 120.dp)
        )
        Icon(
            imageVector = Icons.Default.Close,
            contentDescription = "Remove",
            tint = MaterialTheme.colorScheme.onSurface.copy(alpha = DS.Opacity.m),
            modifier = Modifier
                .size(DS.Icon.s)
                .clip(CircleShape)
                .clickable(onClick = onRemove)
        )
    }
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

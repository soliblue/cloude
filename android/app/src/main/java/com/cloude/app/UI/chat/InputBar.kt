package com.cloude.app.UI.chat

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import android.util.Base64
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.Send
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Image
import androidx.compose.material.icons.filled.Stop
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
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
import com.cloude.app.Utilities.Accent
import com.cloude.app.Utilities.DS
import com.cloude.app.Utilities.PastelRed
import java.io.ByteArrayOutputStream

@Composable
fun InputBar(
    isRunning: Boolean,
    currentEffort: String?,
    currentModel: String?,
    onSend: (String, List<String>?) -> Unit,
    onAbort: () -> Unit,
    onEffortChange: (String?) -> Unit,
    onModelChange: (String?) -> Unit,
    modifier: Modifier = Modifier
) {
    var text by remember { mutableStateOf("") }
    var attachedImages by remember { mutableStateOf<List<Pair<Bitmap, String>>>(emptyList()) }
    val context = LocalContext.current

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

    Column(modifier = modifier) {
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
                modifier = Modifier.padding(bottom = DS.Spacing.xs),
                horizontalArrangement = Arrangement.spacedBy(DS.Spacing.xs)
            ) {
                attachedImages.forEachIndexed { index, (bitmap, _) ->
                    Box {
                        Image(
                            bitmap = bitmap.asImageBitmap(),
                            contentDescription = "Attached image",
                            modifier = Modifier
                                .size(48.dp)
                                .clip(RoundedCornerShape(DS.Radius.s)),
                            contentScale = ContentScale.Crop
                        )
                        Icon(
                            imageVector = Icons.Default.Close,
                            contentDescription = "Remove",
                            tint = MaterialTheme.colorScheme.onPrimary,
                            modifier = Modifier
                                .size(DS.Icon.s)
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
                modifier = Modifier.size(DS.Size.m)
            ) {
                Icon(
                    imageVector = Icons.Default.Image,
                    contentDescription = "Attach image",
                    tint = Accent,
                    modifier = Modifier.size(DS.Icon.m)
                )
            }

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

            if (isRunning) {
                IconButton(onClick = onAbort) {
                    Icon(
                        imageVector = Icons.Default.Stop,
                        contentDescription = "Stop",
                        tint = PastelRed
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

package com.cloude.app.UI.chat

import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.height
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.painterResource
import com.cloude.app.R
import com.cloude.app.Utilities.DS
import kotlinx.coroutines.delay

private val pushFrames = listOf(
    R.drawable.cloude_anim_1,
    R.drawable.cloude_anim_2,
    R.drawable.cloude_anim_3,
    R.drawable.cloude_anim_4,
    R.drawable.cloude_anim_5,
    R.drawable.cloude_anim_6
)

private val retreatFrames = listOf(
    R.drawable.cloude_anim_11,
    R.drawable.cloude_anim_12,
    R.drawable.cloude_anim_13,
    R.drawable.cloude_anim_14,
    R.drawable.cloude_anim_15,
    R.drawable.cloude_anim_16,
    R.drawable.cloude_anim_17,
    R.drawable.cloude_anim_18
)

private val sequence = pushFrames + retreatFrames
private const val FRAME_DURATION_MS = 220L

@Composable
fun SisyphusAnimation(modifier: Modifier = Modifier) {
    var frameIndex by remember { mutableIntStateOf(0) }

    LaunchedEffect(Unit) {
        while (true) {
            delay(FRAME_DURATION_MS)
            frameIndex = (frameIndex + 1) % sequence.size
        }
    }

    Image(
        painter = painterResource(id = sequence[frameIndex]),
        contentDescription = "Loading",
        contentScale = ContentScale.Fit,
        modifier = modifier.height(DS.Size.l)
    )
}

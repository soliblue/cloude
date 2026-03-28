package com.cloude.app.Utilities

import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

object DS {
    object Text {
        val s = 10.sp
        val m = 13.sp
    }

    object Icon {
        val s = 14.dp
        val m = 16.dp
        val l = 19.dp
    }

    object Spacing {
        val xs = 4.dp
        val s = 8.dp
        val m = 12.dp
        val l = 16.dp
        val xl = 24.dp
        val xxl = 32.dp
    }

    object Radius {
        val s = 6.dp
        val m = 9.dp
        val l = 12.dp
    }

    object Size {
        val m = 28.dp
        val l = 44.dp
        val xxl = 200.dp
    }

    object Scale {
        const val s = 0.6f
        const val m = 0.9f
        const val l = 1.2f
    }

    object Stroke {
        val s = 0.6.dp
        val m = 1.2.dp
        val l = 1.8.dp
    }

    object Duration {
        const val s = 200
        const val m = 500
        const val l = 800
    }

    object Opacity {
        const val s = 0.15f
        const val m = 0.4f
        const val l = 0.7f
    }
}

data class ThemePalette(
    val background: Long,
    val secondary: Long
)

enum class AppTheme(val displayName: String) {
    Monet("Monet"),
    Turner("Turner"),
    Malevich("Malevich"),
    Bauder("Bauder"),
    Majorelle("Majorelle"),
    Klimt("Klimt");

    val isLight: Boolean
        get() = this == Monet || this == Turner

    val palette: ThemePalette
        get() = when (this) {
            Monet -> ThemePalette(background = 0xFFFFFFFF, secondary = 0xFFF2F2F7)
            Turner -> ThemePalette(background = 0xFFFDF6E3, secondary = 0xFFEEE8D5)
            Malevich -> ThemePalette(background = 0xFF000000, secondary = 0xFF0A0A0A)
            Bauder -> ThemePalette(background = 0xFF131A24, secondary = 0xFF1A2332)
            Majorelle -> ThemePalette(background = 0xFF0C0F1F, secondary = 0xFF141A35)
            Klimt -> ThemePalette(background = 0xFF141008, secondary = 0xFF221A0C)
        }
}

package com.cloude.app.Utilities

import androidx.compose.ui.graphics.Color

val Accent = Color(0xFFCC7257)

val PastelGreen = Color(0xFF7AB87A)
val PastelRed = Color(0xFFB54E5E)

fun Color.Companion.fromHex(hex: Long): Color = Color(hex)

fun Color.Companion.fromName(name: String?, default: Color = Color.Blue): Color =
    when (name?.lowercase()) {
        "blue" -> Color.Blue
        "green" -> Color.Green
        "red" -> Color.Red
        "purple" -> Color(0xFF9C27B0)
        "orange" -> Color(0xFFFF9800)
        "cyan" -> Color.Cyan
        "magenta", "pink" -> Color(0xFFE91E63)
        "yellow" -> Color.Yellow
        "teal" -> Color(0xFF009688)
        "indigo" -> Color(0xFF3F51B5)
        "mint" -> Color(0xFF00BFA5)
        else -> default
    }

package com.cloude.app.UI.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.compositionLocalOf
import androidx.compose.ui.graphics.Color
import com.cloude.app.Utilities.Accent
import com.cloude.app.Utilities.AppTheme

val LocalAppTheme = compositionLocalOf { AppTheme.Majorelle }

private fun darkScheme(theme: AppTheme) = darkColorScheme(
    primary = Accent,
    onPrimary = Color.White,
    surface = Color(theme.palette.background),
    onSurface = Color.White,
    surfaceVariant = Color(theme.palette.secondary),
    onSurfaceVariant = Color.White.copy(alpha = 0.7f),
    background = Color(theme.palette.background),
    onBackground = Color.White,
    outline = Color.White.copy(alpha = 0.12f),
    surfaceContainerLow = Color(theme.palette.secondary),
    surfaceContainer = Color(theme.palette.secondary),
    surfaceContainerHigh = Color(theme.palette.secondary)
)

private fun lightScheme(theme: AppTheme) = lightColorScheme(
    primary = Accent,
    onPrimary = Color.White,
    surface = Color(theme.palette.background),
    onSurface = Color.Black,
    surfaceVariant = Color(theme.palette.secondary),
    onSurfaceVariant = Color.Black.copy(alpha = 0.7f),
    background = Color(theme.palette.background),
    onBackground = Color.Black,
    outline = Color.Black.copy(alpha = 0.12f),
    surfaceContainerLow = Color(theme.palette.secondary),
    surfaceContainer = Color(theme.palette.secondary),
    surfaceContainerHigh = Color(theme.palette.secondary)
)

@Composable
fun CloudeTheme(
    appTheme: AppTheme = AppTheme.Majorelle,
    content: @Composable () -> Unit
) {
    val colorScheme = if (appTheme.isLight) lightScheme(appTheme) else darkScheme(appTheme)

    CompositionLocalProvider(LocalAppTheme provides appTheme) {
        MaterialTheme(
            colorScheme = colorScheme,
            content = content
        )
    }
}

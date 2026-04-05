package com.cloude.app.UI.settings

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.relocation.BringIntoViewRequester
import androidx.compose.foundation.relocation.bringIntoViewRequester
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.ExperimentalComposeUiApi
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.focus.onFocusEvent
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import kotlinx.coroutines.launch
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import com.cloude.app.Models.EnvironmentStore
import com.cloude.app.Models.ServerEnvironment
import com.cloude.app.Services.ConnectionManager
import com.cloude.app.Utilities.Accent
import com.cloude.app.Utilities.AppTheme
import com.cloude.app.Utilities.DS
import com.cloude.app.Utilities.PastelGreen
import com.cloude.app.Utilities.PastelRed
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp

@Composable
fun SettingsScreen(
    environmentStore: EnvironmentStore,
    connectionManager: ConnectionManager,
    currentTheme: AppTheme,
    onThemeChange: (AppTheme) -> Unit,
    debugOverlayEnabled: Boolean = false,
    onDebugOverlayChange: (Boolean) -> Unit = {},
    modifier: Modifier = Modifier
) {
    val environments by environmentStore.environments.collectAsState()
    var newHost by remember { mutableStateOf("") }
    var newPort by remember { mutableStateOf("8765") }
    var newToken by remember { mutableStateOf("") }

    Column(
        modifier = modifier
            .fillMaxSize()
            .background(MaterialTheme.colorScheme.background)
            .imePadding()
            .verticalScroll(rememberScrollState())
            .padding(DS.Spacing.l)
    ) {
        Text(
            text = "Theme",
            style = MaterialTheme.typography.titleMedium,
            color = MaterialTheme.colorScheme.onBackground
        )

        Spacer(modifier = Modifier.height(DS.Spacing.s))

        Row(
            horizontalArrangement = Arrangement.spacedBy(DS.Spacing.s)
        ) {
            AppTheme.entries.forEach { theme ->
                val isSelected = theme == currentTheme
                Column(
                    horizontalAlignment = Alignment.CenterHorizontally,
                    modifier = Modifier
                        .clickable { onThemeChange(theme) }
                        .padding(DS.Spacing.xs)
                ) {
                    Spacer(
                        modifier = Modifier
                            .size(36.dp)
                            .clip(CircleShape)
                            .background(Color(theme.palette.background))
                            .then(
                                if (isSelected) Modifier.border(2.dp, Accent, CircleShape)
                                else Modifier.border(1.dp, Color.Gray.copy(alpha = 0.3f), CircleShape)
                            )
                    )
                    Text(
                        text = theme.displayName,
                        style = MaterialTheme.typography.labelSmall,
                        color = if (isSelected) Accent
                               else MaterialTheme.colorScheme.onSurface.copy(alpha = DS.Opacity.m)
                    )
                }
            }
        }

        Spacer(modifier = Modifier.height(DS.Spacing.xl))

        Text(
            text = "Environments",
            style = MaterialTheme.typography.titleMedium,
            color = MaterialTheme.colorScheme.onBackground
        )

        Spacer(modifier = Modifier.height(DS.Spacing.m))

        environments.forEach { env ->
            EnvironmentCard(
                env = env,
                connectionManager = connectionManager,
                onDelete = {
                    connectionManager.disconnectEnvironment(env.id)
                    environmentStore.delete(env.id)
                }
            )
            Spacer(modifier = Modifier.height(DS.Spacing.s))
        }

        Spacer(modifier = Modifier.height(DS.Spacing.l))

        Text(
            text = "Add Environment",
            style = MaterialTheme.typography.titleSmall,
            color = MaterialTheme.colorScheme.onBackground
        )

        Spacer(modifier = Modifier.height(DS.Spacing.s))

        SettingsTextField(value = newHost, onValueChange = { newHost = it }, placeholder = "Host (e.g. cloude.example.com)")
        Spacer(modifier = Modifier.height(DS.Spacing.s))
        SettingsTextField(value = newPort, onValueChange = { newPort = it }, placeholder = "Port", keyboardType = KeyboardType.Number)
        Spacer(modifier = Modifier.height(DS.Spacing.s))
        SettingsTextField(value = newToken, onValueChange = { newToken = it }, placeholder = "Auth Token", isPassword = true)
        Spacer(modifier = Modifier.height(DS.Spacing.m))

        Button(
            onClick = {
                if (newHost.isNotBlank() && newToken.isNotBlank()) {
                    val env = environmentStore.createNew(
                        host = newHost.trim(),
                        port = newPort.toIntOrNull() ?: 8765,
                        token = newToken.trim()
                    )
                    connectionManager.connectEnvironment(env)
                    newHost = ""
                    newPort = "8765"
                    newToken = ""
                }
            },
            colors = ButtonDefaults.buttonColors(containerColor = Accent),
            enabled = newHost.isNotBlank() && newToken.isNotBlank()
        ) {
            Icon(Icons.Default.Add, contentDescription = null, modifier = Modifier.size(DS.Icon.m))
            Text(" Add", style = MaterialTheme.typography.labelLarge)
        }

        Spacer(modifier = Modifier.height(DS.Spacing.xl))

        Text(
            text = "Developer",
            style = MaterialTheme.typography.titleMedium,
            color = MaterialTheme.colorScheme.onBackground
        )

        Spacer(modifier = Modifier.height(DS.Spacing.m))

        Row(
            modifier = Modifier
                .fillMaxWidth()
                .background(MaterialTheme.colorScheme.surfaceVariant, RoundedCornerShape(DS.Radius.m))
                .padding(horizontal = DS.Spacing.m, vertical = DS.Spacing.s),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween
        ) {
            Text(
                text = "Debug Overlay",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurface
            )
            Switch(
                checked = debugOverlayEnabled,
                onCheckedChange = onDebugOverlayChange,
                colors = SwitchDefaults.colors(checkedTrackColor = Accent)
            )
        }
    }
}

@Composable
private fun EnvironmentCard(
    env: ServerEnvironment,
    connectionManager: ConnectionManager,
    onDelete: () -> Unit
) {
    val conn = connectionManager.connection(env.id)
    val isConnected = conn?.isConnected?.collectAsState()?.value ?: false
    val isAuthenticated = conn?.isAuthenticated?.collectAsState()?.value ?: false

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .background(MaterialTheme.colorScheme.surfaceVariant, RoundedCornerShape(DS.Radius.m))
            .padding(DS.Spacing.m),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(DS.Spacing.m)
    ) {
        Spacer(
            modifier = Modifier
                .size(DS.Spacing.s)
                .clip(CircleShape)
                .background(if (isAuthenticated) PastelGreen else if (isConnected) Accent else PastelRed)
        )
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = env.host,
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurface
            )
            Text(
                text = "Port ${env.port}",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = DS.Opacity.l)
            )
        }
        IconButton(onClick = onDelete) {
            Icon(
                Icons.Default.Delete,
                contentDescription = "Delete",
                tint = MaterialTheme.colorScheme.onSurface.copy(alpha = DS.Opacity.m)
            )
        }
    }
}

@OptIn(ExperimentalComposeUiApi::class, ExperimentalFoundationApi::class)
@Composable
private fun SettingsTextField(
    value: String,
    onValueChange: (String) -> Unit,
    placeholder: String,
    keyboardType: KeyboardType = KeyboardType.Text,
    isPassword: Boolean = false
) {
    val bringIntoViewRequester = remember { BringIntoViewRequester() }
    val coroutineScope = rememberCoroutineScope()

    BasicTextField(
        value = value,
        onValueChange = onValueChange,
        modifier = Modifier
            .fillMaxWidth()
            .bringIntoViewRequester(bringIntoViewRequester)
            .onFocusEvent { if (it.isFocused) coroutineScope.launch { bringIntoViewRequester.bringIntoView() } }
            .background(MaterialTheme.colorScheme.surfaceVariant, RoundedCornerShape(DS.Radius.m))
            .padding(horizontal = DS.Spacing.m, vertical = DS.Spacing.m),
        textStyle = MaterialTheme.typography.bodyMedium.copy(
            color = MaterialTheme.colorScheme.onSurface
        ),
        cursorBrush = SolidColor(Accent),
        keyboardOptions = KeyboardOptions(keyboardType = keyboardType),
        visualTransformation = if (isPassword) PasswordVisualTransformation() else androidx.compose.ui.text.input.VisualTransformation.None,
        decorationBox = { innerTextField ->
            if (value.isEmpty()) {
                Text(
                    text = placeholder,
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = DS.Opacity.m)
                )
            }
            innerTextField()
        }
    )
}

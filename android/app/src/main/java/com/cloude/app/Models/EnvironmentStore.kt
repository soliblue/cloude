package com.cloude.app.Models

import android.content.Context
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import java.io.File
import java.util.UUID

class EnvironmentStore(private val context: Context) {
    private val _environments = MutableStateFlow<List<ServerEnvironment>>(emptyList())
    val environments: StateFlow<List<ServerEnvironment>> = _environments

    private val _activeEnvironmentId = MutableStateFlow<String?>(null)
    val activeEnvironmentId: StateFlow<String?> = _activeEnvironmentId

    val activeEnvironment: ServerEnvironment?
        get() = _environments.value.firstOrNull { it.id == _activeEnvironmentId.value }

    private val file: File
        get() = File(context.filesDir, "environments.json")

    private val prefs = context.getSharedPreferences("cloude", Context.MODE_PRIVATE)

    init {
        load()
    }

    private fun load() {
        if (file.exists()) {
            val saved = Json.decodeFromString<List<ServerEnvironment>>(file.readText())
            _environments.value = saved
            _activeEnvironmentId.value = prefs.getString("activeEnvironmentId", null)
            if (activeEnvironment == null) {
                _environments.value.firstOrNull()?.let { setActive(it.id) }
            }
        }
    }

    fun save() {
        file.writeText(Json.encodeToString(_environments.value))
    }

    fun add(env: ServerEnvironment) {
        _environments.value = _environments.value + env
        if (_environments.value.size == 1) setActive(env.id)
        save()
    }

    fun update(env: ServerEnvironment) {
        _environments.value = _environments.value.map { if (it.id == env.id) env else it }
        save()
    }

    fun delete(envId: String) {
        _environments.value = _environments.value.filter { it.id != envId }
        if (_activeEnvironmentId.value == envId) {
            setActive(_environments.value.firstOrNull()?.id)
        }
        save()
    }

    fun setActive(envId: String?) {
        _activeEnvironmentId.value = envId
        prefs.edit().putString("activeEnvironmentId", envId).apply()
    }

    fun createNew(host: String, port: Int = 8765, token: String): ServerEnvironment {
        val env = ServerEnvironment(
            id = UUID.randomUUID().toString(),
            host = host,
            port = port,
            token = token
        )
        add(env)
        return env
    }
}

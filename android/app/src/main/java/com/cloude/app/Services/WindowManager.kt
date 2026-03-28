package com.cloude.app.Services

import android.content.Context
import com.cloude.app.Models.ChatWindow
import com.cloude.app.Models.WindowType
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import org.json.JSONArray
import org.json.JSONObject

class WindowManager(context: Context) {
    private val prefs = context.getSharedPreferences("windows", Context.MODE_PRIVATE)
    private val _windows = MutableStateFlow(loadWindows())
    val windows: StateFlow<List<ChatWindow>> = _windows.asStateFlow()

    private val _activeIndex = MutableStateFlow(prefs.getInt("activeIndex", 0))
    val activeIndex: StateFlow<Int> = _activeIndex.asStateFlow()

    val activeWindow: ChatWindow?
        get() = _windows.value.getOrNull(_activeIndex.value)

    fun addWindow(type: WindowType = WindowType.Chat): ChatWindow? {
        if (_windows.value.size >= 5) return null
        val window = ChatWindow(type = type)
        _windows.value = _windows.value + window
        _activeIndex.value = _windows.value.lastIndex
        save()
        return window
    }

    fun removeWindow(id: String) {
        val index = _windows.value.indexOfFirst { it.id == id }
        if (index == -1 || _windows.value.size <= 1) return
        _windows.value = _windows.value.filter { it.id != id }
        if (_activeIndex.value >= _windows.value.size) {
            _activeIndex.value = _windows.value.lastIndex
        }
        save()
    }

    fun setActive(index: Int) {
        if (index in _windows.value.indices) {
            _activeIndex.value = index
            prefs.edit().putInt("activeIndex", index).apply()
        }
    }

    fun setWindowType(id: String, type: WindowType) {
        _windows.value = _windows.value.map {
            if (it.id == id) it.copy(type = type) else it
        }
        save()
    }

    fun setConversationId(id: String, conversationId: String?) {
        _windows.value = _windows.value.map {
            if (it.id == id) it.copy(conversationId = conversationId) else it
        }
        save()
    }

    private fun save() {
        val json = JSONArray()
        _windows.value.forEach { w ->
            json.put(JSONObject().apply {
                put("id", w.id)
                put("type", w.type.name)
                put("conversationId", w.conversationId ?: JSONObject.NULL)
            })
        }
        prefs.edit()
            .putString("windows", json.toString())
            .putInt("activeIndex", _activeIndex.value)
            .apply()
    }

    private fun loadWindows(): List<ChatWindow> {
        val raw = prefs.getString("windows", null) ?: return listOf(ChatWindow())
        val json = JSONArray(raw)
        val result = (0 until json.length()).map { i ->
            val obj = json.getJSONObject(i)
            ChatWindow(
                id = obj.getString("id"),
                type = WindowType.valueOf(obj.getString("type")),
                conversationId = if (obj.isNull("conversationId")) null else obj.getString("conversationId")
            )
        }
        return result.ifEmpty { listOf(ChatWindow()) }
    }
}

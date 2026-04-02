package com.cloude.app.Models

import java.util.Date
import java.util.UUID

data class MemoryItem(
    val id: String = UUID.randomUUID().toString(),
    val content: String,
    val timestamp: Date? = null,
    val isBullet: Boolean = true
)

data class ParsedMemorySection(
    val id: String,
    val title: String,
    val icon: String? = null,
    val items: List<MemoryItem> = emptyList(),
    val subsections: List<ParsedMemorySection> = emptyList()
) {
    val childCount: Int
        get() = items.size + subsections.sumOf { it.childCount + 1 }
}

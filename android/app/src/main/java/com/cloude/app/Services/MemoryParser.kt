package com.cloude.app.Services

import com.cloude.app.Models.MemoryItem
import com.cloude.app.Models.MemorySection
import com.cloude.app.Models.ParsedMemorySection
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

object MemoryParser {
    fun parse(sections: List<MemorySection>): List<ParsedMemorySection> =
        sections.map { parseSection(id = it.title, title = it.title, content = it.content, level = 2) }

    private fun parseSection(id: String, title: String, content: String, level: Int): ParsedMemorySection {
        val (cleanTitle, icon) = extractIcon(title)
        val headerPrefix = "#".repeat(level + 1) + " "
        val lines = content.split("\n")

        val topLevelContent = mutableListOf<String>()
        val subsections = mutableListOf<ParsedMemorySection>()
        var currentSubTitle: String? = null
        var currentSubContent = mutableListOf<String>()

        for (line in lines) {
            if (line.startsWith(headerPrefix)) {
                currentSubTitle?.let { subTitle ->
                    val (cleanSub, _) = extractIcon(subTitle)
                    subsections.add(parseSection(
                        id = "$id/$cleanSub",
                        title = subTitle,
                        content = currentSubContent.joinToString("\n"),
                        level = level + 1
                    ))
                }
                currentSubTitle = line.removePrefix(headerPrefix).trim()
                currentSubContent = mutableListOf()
            } else if (currentSubTitle != null) {
                currentSubContent.add(line)
            } else {
                topLevelContent.add(line)
            }
        }

        currentSubTitle?.let { subTitle ->
            val (cleanSub, _) = extractIcon(subTitle)
            subsections.add(parseSection(
                id = "$id/$cleanSub",
                title = subTitle,
                content = currentSubContent.joinToString("\n"),
                level = level + 1
            ))
        }

        val items = parseItems(topLevelContent.joinToString("\n"))

        return ParsedMemorySection(
            id = id,
            title = cleanTitle,
            icon = icon,
            items = items,
            subsections = subsections
        )
    }

    private fun extractIcon(title: String): Pair<String, String?> {
        val match = Regex("^(.+?)\\s*\\{([a-z0-9.]+)}$", RegexOption.IGNORE_CASE).find(title)
            ?: return title to null
        return match.groupValues[1].trim() to match.groupValues[2]
    }

    private fun parseItems(content: String): List<MemoryItem> {
        val items = mutableListOf<MemoryItem>()
        val paragraphBuffer = mutableListOf<String>()

        for (line in content.split("\n")) {
            val trimmed = line.trim()
            if (trimmed.startsWith("- ")) {
                if (paragraphBuffer.isNotEmpty()) {
                    val text = paragraphBuffer.joinToString(" ")
                    if (text.isNotEmpty()) items.add(MemoryItem(content = text, isBullet = false))
                    paragraphBuffer.clear()
                }
                val bulletContent = trimmed.removePrefix("- ")
                val (text, date) = extractTimestamp(bulletContent)
                items.add(MemoryItem(content = text, timestamp = date, isBullet = true))
            } else if (trimmed.isEmpty()) {
                if (paragraphBuffer.isNotEmpty()) {
                    val text = paragraphBuffer.joinToString(" ")
                    if (text.isNotEmpty()) items.add(MemoryItem(content = text, isBullet = false))
                    paragraphBuffer.clear()
                }
            } else {
                paragraphBuffer.add(trimmed)
            }
        }

        if (paragraphBuffer.isNotEmpty()) {
            val text = paragraphBuffer.joinToString(" ")
            if (text.isNotEmpty()) items.add(MemoryItem(content = text, isBullet = false))
        }

        return items
    }

    private fun extractTimestamp(text: String): Pair<String, Date?> {
        val patterns = listOf(
            Regex("^\\*\\*([0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2})\\*\\*:\\s*"),
            Regex("^\\*\\*([0-9]{4}-[0-9]{2}-[0-9]{2})\\*\\*:\\s*")
        )
        for (pattern in patterns) {
            val match = pattern.find(text) ?: continue
            val dateStr = match.groupValues[1]
            val remaining = text.substring(match.range.last + 1)
            val format = if (dateStr.length > 10) "yyyy-MM-dd HH:mm" else "yyyy-MM-dd"
            val date = SimpleDateFormat(format, Locale.US).parse(dateStr)
            return remaining to date
        }
        return text to null
    }
}

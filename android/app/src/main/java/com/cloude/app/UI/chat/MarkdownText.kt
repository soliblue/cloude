package com.cloude.app.UI.chat

import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.PressInteraction
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.IntrinsicSize
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.VerticalDivider
import androidx.compose.runtime.Composable
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalUriHandler
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.TextLayoutResult
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.cloude.app.Utilities.DS

@Composable
fun MarkdownText(
    text: String,
    color: Color = MaterialTheme.colorScheme.onSurface,
    onLongPress: (() -> Unit)? = null,
    interactionSource: MutableInteractionSource? = null,
    modifier: Modifier = Modifier
) {
    val blocks = parseBlocks(text)
    val uriHandler = LocalUriHandler.current
    val codeBackground = MaterialTheme.colorScheme.surface
    val inlineCodeBackground = MaterialTheme.colorScheme.surface
    val linkColor = MaterialTheme.colorScheme.primary

    Column(modifier = modifier) {
        blocks.forEach { block ->
            when (block) {
                is Block.CodeBlock -> {
                    Column(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(vertical = DS.Spacing.xs)
                            .clip(RoundedCornerShape(DS.Radius.m))
                            .background(codeBackground)
                    ) {
                        if (block.language.isNotEmpty()) {
                            Text(
                                text = block.language,
                                style = MaterialTheme.typography.labelSmall,
                                color = color.copy(alpha = DS.Opacity.m),
                                modifier = Modifier.padding(
                                    start = DS.Spacing.m,
                                    top = DS.Spacing.s,
                                    end = DS.Spacing.m
                                )
                            )
                        }
                        Text(
                            text = block.code,
                            style = MaterialTheme.typography.bodySmall.copy(
                                fontFamily = FontFamily.Monospace,
                                lineHeight = 18.sp
                            ),
                            color = color,
                            modifier = Modifier
                                .horizontalScroll(rememberScrollState())
                                .padding(DS.Spacing.m)
                        )
                    }
                }

                is Block.Heading -> {
                    val style = when (block.level) {
                        1 -> MaterialTheme.typography.titleLarge
                        2 -> MaterialTheme.typography.titleMedium
                        else -> MaterialTheme.typography.titleSmall
                    }
                    Text(
                        text = parseInline(block.text, color, inlineCodeBackground, linkColor),
                        style = style,
                        modifier = Modifier.padding(vertical = DS.Spacing.xs)
                    )
                }

                is Block.Quote -> {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(vertical = DS.Spacing.xs)
                    ) {
                        androidx.compose.foundation.Canvas(
                            modifier = Modifier
                                .padding(end = DS.Spacing.s)
                                .fillMaxWidth(0.01f)
                        ) {}
                        Column(
                            modifier = Modifier
                                .padding(start = DS.Spacing.s)
                                .background(
                                    color.copy(alpha = 0.05f),
                                    RoundedCornerShape(DS.Radius.s)
                                )
                                .padding(DS.Spacing.s)
                        ) {
                            val annotated = parseInline(block.text, color.copy(alpha = 0.8f), inlineCodeBackground, linkColor)
                            Text(
                                text = annotated,
                                style = MaterialTheme.typography.bodyMedium.copy(
                                    fontStyle = FontStyle.Italic
                                )
                            )
                        }
                    }
                }

                is Block.ListItem -> {
                    val bullet = when {
                        block.checked != null -> if (block.checked) "\u2611" else "\u2610"
                        block.ordered -> "${block.index}."
                        else -> "\u2022"
                    }
                    val indentDp = (DS.Spacing.m + DS.Spacing.l * block.indent)
                    Row(
                        modifier = Modifier.padding(
                            start = indentDp,
                            top = 2.dp,
                            bottom = 2.dp
                        )
                    ) {
                        Text(
                            text = "$bullet ",
                            style = MaterialTheme.typography.bodyMedium,
                            color = if (block.checked == true) color.copy(alpha = DS.Opacity.m) else color
                        )
                        val annotated = parseInline(block.text, color, inlineCodeBackground, linkColor)
                        val layoutResult = remember { mutableStateOf<TextLayoutResult?>(null) }
                        Text(
                            text = annotated,
                            style = MaterialTheme.typography.bodyMedium,
                            onTextLayout = { layoutResult.value = it },
                            modifier = Modifier.pointerInput(onLongPress, interactionSource) {
                                detectTapGestures(
                                    onPress = { offset ->
                                        val press = interactionSource?.let {
                                            PressInteraction.Press(Offset(offset.x, offset.y)).also { p -> it.emit(p) }
                                        }
                                        val released = tryAwaitRelease()
                                        press?.let { p ->
                                            interactionSource?.emit(
                                                if (released) PressInteraction.Release(p) else PressInteraction.Cancel(p)
                                            )
                                        }
                                    },
                                    onTap = { pos ->
                                        layoutResult.value?.let { layout ->
                                            val offset = layout.getOffsetForPosition(pos)
                                            annotated.getStringAnnotations("URL", offset, offset)
                                                .firstOrNull()?.let { uriHandler.openUri(it.item) }
                                        }
                                    },
                                    onLongPress = { onLongPress?.invoke() }
                                )
                            }
                        )
                    }
                }

                is Block.Table -> {
                    val dividerColor = color.copy(alpha = 0.2f)
                    val headerBg = Color.Gray.copy(alpha = DS.Opacity.s)
                    val colCount = block.rows.maxOfOrNull { it.size } ?: 0
                    Column(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(vertical = DS.Spacing.xs)
                            .clip(RoundedCornerShape(DS.Radius.s))
                            .background(color.copy(alpha = 0.03f))
                    ) {
                        block.rows.forEachIndexed { rowIndex, row ->
                            if (rowIndex > 0) {
                                HorizontalDivider(color = dividerColor, thickness = 0.5.dp)
                            }
                            Row(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .height(IntrinsicSize.Min)
                                    .then(if (rowIndex == 0) Modifier.background(headerBg) else Modifier)
                            ) {
                                (0 until colCount).forEach { colIndex ->
                                    if (colIndex > 0) {
                                        VerticalDivider(
                                            modifier = Modifier.fillMaxHeight(),
                                            color = dividerColor,
                                            thickness = 0.5.dp
                                        )
                                    }
                                    val cell = row.getOrElse(colIndex) { "" }
                                    Text(
                                        text = parseInline(cell.trim(), color, inlineCodeBackground, linkColor),
                                        style = MaterialTheme.typography.bodySmall.copy(
                                            fontWeight = if (rowIndex == 0) FontWeight.Bold else FontWeight.Normal
                                        ),
                                        modifier = Modifier
                                            .weight(1f)
                                            .padding(horizontal = DS.Spacing.s, vertical = DS.Spacing.s)
                                    )
                                }
                            }
                        }
                    }
                }

                is Block.HorizontalRule -> {
                    HorizontalDivider(
                        modifier = Modifier.padding(vertical = DS.Spacing.s),
                        color = color.copy(alpha = 0.2f)
                    )
                }

                is Block.Paragraph -> {
                    val annotated = parseInline(block.text, color, inlineCodeBackground, linkColor)
                    val layoutResult = remember { mutableStateOf<TextLayoutResult?>(null) }
                    Text(
                        text = annotated,
                        style = MaterialTheme.typography.bodyMedium,
                        onTextLayout = { layoutResult.value = it },
                        modifier = Modifier
                            .padding(vertical = 2.dp)
                            .pointerInput(onLongPress, interactionSource) {
                                detectTapGestures(
                                    onPress = { offset ->
                                        val press = interactionSource?.let {
                                            PressInteraction.Press(Offset(offset.x, offset.y)).also { p -> it.emit(p) }
                                        }
                                        val released = tryAwaitRelease()
                                        press?.let { p ->
                                            interactionSource?.emit(
                                                if (released) PressInteraction.Release(p) else PressInteraction.Cancel(p)
                                            )
                                        }
                                    },
                                    onTap = { pos ->
                                        layoutResult.value?.let { layout ->
                                            val offset = layout.getOffsetForPosition(pos)
                                            annotated.getStringAnnotations("URL", offset, offset)
                                                .firstOrNull()?.let { uriHandler.openUri(it.item) }
                                        }
                                    },
                                    onLongPress = { onLongPress?.invoke() }
                                )
                            }
                    )
                }
            }
        }
    }
}

private sealed class Block {
    data class Paragraph(val text: String) : Block()
    data class CodeBlock(val code: String, val language: String) : Block()
    data class Heading(val text: String, val level: Int) : Block()
    data class Quote(val text: String) : Block()
    data class ListItem(val text: String, val ordered: Boolean, val index: Int, val indent: Int = 0, val checked: Boolean? = null) : Block()
    data class Table(val rows: List<List<String>>) : Block()
    data object HorizontalRule : Block()
}

private val UNORDERED_RE = Regex("^(\\s*)([-*+]) (.*)")
private val ORDERED_RE = Regex("^(\\s*)(\\d+)\\. (.*)")
private val TASK_RE = Regex("^(\\s*)[-*+] \\[([ xX])] (.*)")
private val TABLE_RE = Regex("^\\|.*\\|\\s*$")
private val TABLE_SEP_RE = Regex("^\\|[\\s:|-]+\\|\\s*$")

private fun parseBlocks(text: String): List<Block> {
    val blocks = mutableListOf<Block>()
    val lines = text.lines()
    var i = 0

    while (i < lines.size) {
        val line = lines[i]
        val trimmed = line.trimStart()

        if (trimmed.startsWith("```")) {
            val language = trimmed.removePrefix("```").trim()
            val codeLines = mutableListOf<String>()
            i++
            while (i < lines.size && !lines[i].trimStart().startsWith("```")) {
                codeLines.add(lines[i])
                i++
            }
            blocks.add(Block.CodeBlock(codeLines.joinToString("\n"), language))
            i++
            continue
        }

        if (TABLE_RE.matches(line.trim())) {
            val tableRows = mutableListOf<List<String>>()
            while (i < lines.size && TABLE_RE.matches(lines[i].trim())) {
                val tableLine = lines[i].trim()
                if (!TABLE_SEP_RE.matches(tableLine)) {
                    val cells = tableLine.removePrefix("|").removeSuffix("|").split("|")
                    tableRows.add(cells.map { it.trim() })
                }
                i++
            }
            if (tableRows.isNotEmpty()) {
                blocks.add(Block.Table(tableRows))
            }
            continue
        }

        if (trimmed.startsWith("#")) {
            val level = trimmed.takeWhile { it == '#' }.length
            if (level in 1..6 && trimmed.getOrNull(level) == ' ') {
                blocks.add(Block.Heading(trimmed.drop(level + 1), level))
                i++
                continue
            }
        }

        if (trimmed.startsWith("> ")) {
            val quoteLines = mutableListOf(trimmed.removePrefix("> "))
            i++
            while (i < lines.size && lines[i].trimStart().startsWith("> ")) {
                quoteLines.add(lines[i].trimStart().removePrefix("> "))
                i++
            }
            blocks.add(Block.Quote(quoteLines.joinToString("\n")))
            continue
        }

        TASK_RE.matchEntire(line)?.let { m ->
            val indent = m.groupValues[1].length / 2
            val checked = m.groupValues[2] != " "
            blocks.add(Block.ListItem(m.groupValues[3], ordered = false, index = 0, indent = indent, checked = checked))
            i++
            return@let
        }?.also { continue }

        UNORDERED_RE.matchEntire(line)?.let { m ->
            val indent = m.groupValues[1].length / 2
            blocks.add(Block.ListItem(m.groupValues[3], ordered = false, index = 0, indent = indent))
            i++
            return@let
        }?.also { continue }

        ORDERED_RE.matchEntire(line)?.let { m ->
            val indent = m.groupValues[1].length / 2
            val num = m.groupValues[2].toIntOrNull() ?: 1
            blocks.add(Block.ListItem(m.groupValues[3], ordered = true, index = num, indent = indent))
            i++
            return@let
        }?.also { continue }

        if (trimmed.matches(Regex("^[-*_]{3,}$"))) {
            blocks.add(Block.HorizontalRule)
            i++
            continue
        }

        if (trimmed.isEmpty()) {
            i++
            continue
        }

        val paraLines = mutableListOf(line)
        i++
        while (i < lines.size) {
            val next = lines[i]
            val nextTrimmed = next.trimStart()
            if (nextTrimmed.isEmpty() || nextTrimmed.startsWith("```") ||
                nextTrimmed.startsWith("#") || nextTrimmed.startsWith("> ") ||
                TABLE_RE.matches(next.trim()) ||
                TASK_RE.matches(next) ||
                UNORDERED_RE.matches(next) ||
                ORDERED_RE.matches(next) ||
                nextTrimmed.matches(Regex("^[-*_]{3,}$"))) break
            paraLines.add(next)
            i++
        }
        blocks.add(Block.Paragraph(paraLines.joinToString("\n")))
    }

    return blocks
}

private fun parseInline(
    text: String,
    color: Color,
    codeBackground: Color,
    linkColor: Color
): AnnotatedString = buildAnnotatedString {
    var i = 0
    val chars = text.toCharArray()

    fun peek(offset: Int = 0) = chars.getOrNull(i + offset)
    fun match(s: String): Boolean {
        if (i + s.length > chars.size) return false
        return text.substring(i, i + s.length) == s
    }

    while (i < chars.size) {
        if (match("**") || match("__")) {
            val delim = text.substring(i, i + 2)
            val end = text.indexOf(delim, i + 2)
            if (end > i + 2) {
                withStyle(SpanStyle(fontWeight = FontWeight.Bold, color = color)) {
                    append(text.substring(i + 2, end))
                }
                i = end + 2
                continue
            }
        }

        if (match("~~")) {
            val end = text.indexOf("~~", i + 2)
            if (end > i + 2) {
                withStyle(SpanStyle(textDecoration = TextDecoration.LineThrough, color = color)) {
                    append(text.substring(i + 2, end))
                }
                i = end + 2
                continue
            }
        }

        if ((peek() == '*' || peek() == '_') && peek(1) != null && peek(1) != ' ') {
            val delim = chars[i]
            if (!match("**") && !match("__")) {
                val end = text.indexOf(delim, i + 1)
                if (end > i + 1 && text[end - 1] != ' ') {
                    withStyle(SpanStyle(fontStyle = FontStyle.Italic, color = color)) {
                        append(text.substring(i + 1, end))
                    }
                    i = end + 1
                    continue
                }
            }
        }

        if (peek() == '`' && !match("```")) {
            val end = text.indexOf('`', i + 1)
            if (end > i + 1) {
                withStyle(SpanStyle(
                    fontFamily = FontFamily.Monospace,
                    background = codeBackground,
                    color = color,
                    fontSize = 13.sp
                )) {
                    append(" ${text.substring(i + 1, end)} ")
                }
                i = end + 1
                continue
            }
        }

        if (peek() == '[') {
            val closeBracket = text.indexOf(']', i + 1)
            if (closeBracket > i + 1 && text.getOrNull(closeBracket + 1) == '(') {
                val closeParen = text.indexOf(')', closeBracket + 2)
                if (closeParen > closeBracket + 2) {
                    val linkText = text.substring(i + 1, closeBracket)
                    val url = text.substring(closeBracket + 2, closeParen)
                    pushStringAnnotation("URL", url)
                    withStyle(SpanStyle(
                        color = linkColor,
                        textDecoration = TextDecoration.Underline
                    )) {
                        append(linkText)
                    }
                    pop()
                    i = closeParen + 1
                    continue
                }
            }
        }

        withStyle(SpanStyle(color = color)) {
            append(chars[i])
        }
        i++
    }
}

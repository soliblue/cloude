package com.cloude.app.UI.files

object YAMLParser {
    fun parse(text: String): Any? {
        val lines = text.split("\n")
        val (result, _) = parseBlock(lines, 0, 0)
        return result
    }

    private fun parseBlock(lines: List<String>, startIndex: Int, minIndent: Int): Pair<Any?, Int> {
        var index = startIndex
        while (index < lines.size) {
            val line = lines[index]
            val trimmed = line.trim()
            if (trimmed.isEmpty() || trimmed.startsWith("#")) {
                index++
                continue
            }
            if (trimmed.startsWith("- ")) {
                return parseArray(lines, index, indentOf(line))
            } else if (trimmed.contains(":")) {
                return parseDictionary(lines, index, indentOf(line))
            }
            break
        }
        return null to index
    }

    private fun parseDictionary(lines: List<String>, startIndex: Int, minIndent: Int): Pair<Map<String, Any?>, Int> {
        val dict = mutableMapOf<String, Any?>()
        var index = startIndex

        while (index < lines.size) {
            val line = lines[index]
            val lineIndent = indentOf(line)
            val trimmed = line.trim()

            if (trimmed.isEmpty() || trimmed.startsWith("#") || trimmed == "---") {
                index++
                continue
            }

            if (lineIndent < minIndent || lineIndent > minIndent) break

            val colonIdx = trimmed.indexOf(':')
            if (colonIdx < 0) {
                index++
                continue
            }

            val key = trimmed.substring(0, colonIdx).trim()
            val afterColon = trimmed.substring(colonIdx + 1).trim()

            if (afterColon.isEmpty()) {
                index++
                if (index < lines.size) {
                    val nextLine = lines[index]
                    val nextTrimmed = nextLine.trim()
                    val nextIndent = indentOf(nextLine)
                    if (nextTrimmed.isNotEmpty() && nextIndent > minIndent) {
                        val (child, newIndex) = parseBlock(lines, index, nextIndent)
                        dict[key] = child ?: ""
                        index = newIndex
                    } else {
                        dict[key] = ""
                    }
                }
            } else {
                dict[key] = parseScalar(afterColon)
                index++
            }
        }
        return dict to index
    }

    private fun parseArray(lines: List<String>, startIndex: Int, minIndent: Int): Pair<List<Any?>, Int> {
        val arr = mutableListOf<Any?>()
        var index = startIndex

        while (index < lines.size) {
            val line = lines[index]
            val lineIndent = indentOf(line)
            val trimmed = line.trim()

            if (trimmed.isEmpty() || trimmed.startsWith("#")) {
                index++
                continue
            }

            if (lineIndent < minIndent || lineIndent > minIndent) break

            if (trimmed.startsWith("- ")) {
                val value = trimmed.removePrefix("- ").trim()
                if (value.contains(":") && !value.startsWith("\"") && !value.startsWith("'")) {
                    val itemIndent = lineIndent + 2
                    val reconstructed = " ".repeat(itemIndent) + value
                    val subLines = mutableListOf(reconstructed)
                    var subIndex = index + 1
                    while (subIndex < lines.size) {
                        val subLine = lines[subIndex]
                        val subTrimmed = subLine.trim()
                        if (subTrimmed.isEmpty() || subTrimmed.startsWith("#")) {
                            subIndex++
                            continue
                        }
                        if (indentOf(subLine) > lineIndent) {
                            subLines.add(subLine)
                            subIndex++
                        } else {
                            break
                        }
                    }
                    val (child, _) = parseDictionary(subLines, 0, itemIndent)
                    arr.add(child)
                    index = subIndex
                } else {
                    arr.add(parseScalar(value))
                    index++
                }
            } else {
                break
            }
        }
        return arr to index
    }

    private fun parseScalar(value: String): Any? {
        if (value == "true" || value == "True" || value == "yes") return true
        if (value == "false" || value == "False" || value == "no") return false
        if (value == "null" || value == "~" || value.isEmpty()) return null

        if ((value.startsWith("\"") && value.endsWith("\"")) ||
            (value.startsWith("'") && value.endsWith("'"))) {
            return value.drop(1).dropLast(1)
        }

        value.toLongOrNull()?.let { return it }
        value.toDoubleOrNull()?.let { return it }

        if (value.startsWith("[") && value.endsWith("]")) {
            val inner = value.drop(1).dropLast(1)
            return inner.split(",").map { parseScalar(it.trim()) }
        }

        return value
    }

    private fun indentOf(line: String): Int = line.takeWhile { it == ' ' }.length
}

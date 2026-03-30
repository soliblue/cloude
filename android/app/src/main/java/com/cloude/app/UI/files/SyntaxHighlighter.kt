package com.cloude.app.UI.files

import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString

object SyntaxHighlighter {
    val keywordColor = Color(0xFF5B9BD5)
    val stringColor = Color(0xFF6AAF6A)
    val commentColor = Color(0xFF9E9E9E)
    val numberColor = Color(0xFFD19A66)
    val typeColor = Color(0xFFC678DD)

    private val keywords = setOf(
        "func", "var", "let", "if", "else", "for", "while", "return", "import", "struct", "class", "enum", "switch", "case", "break", "continue", "guard", "defer", "try", "catch", "throw", "throws", "async", "await", "private", "public", "internal", "static", "override", "final", "self", "super", "init", "deinit", "extension", "protocol", "where", "in", "as", "is", "nil", "true", "false",
        "function", "const", "export", "default", "from", "new", "this", "typeof", "instanceof", "undefined", "null",
        "def", "elif", "pass", "with", "lambda", "yield", "global", "nonlocal", "assert", "raise", "except", "finally", "and", "or", "not", "None", "True", "False",
        "fn", "mut", "pub", "mod", "use", "impl", "trait", "match", "loop", "move", "ref", "unsafe", "extern", "crate", "type", "dyn", "Some", "Ok", "Err",
        "package", "go", "chan", "select", "range", "fallthrough", "make", "map", "interface", "iota",
        "fun", "val", "when", "object", "companion", "data", "sealed", "abstract", "open", "inner", "suspend", "inline", "crossinline", "noinline", "reified", "typealias", "annotation"
    )

    private val types = setOf(
        "String", "Int", "Double", "Float", "Bool", "Array", "Dictionary", "Set", "Optional", "Result", "Error", "View", "some", "any", "Self",
        "number", "string", "boolean", "object", "void", "never", "unknown",
        "str", "int", "float", "bool", "list", "dict", "tuple", "set", "bytes",
        "i8", "i16", "i32", "i64", "i128", "u8", "u16", "u32", "u64", "u128", "f32", "f64", "usize", "isize", "Vec", "Box", "Rc", "Arc", "Option",
        "Unit", "Nothing", "Any", "Boolean", "Byte", "Short", "Long", "Char", "List", "Map", "MutableList", "MutableMap"
    )

    private val hashCommentLanguages = setOf("python", "ruby", "bash", "yaml", "toml", "r", "sh")

    private val extensionMap = mapOf(
        "swift" to "swift", "m" to "objectivec", "h" to "objectivec",
        "c" to "c", "cpp" to "cpp", "hpp" to "cpp",
        "py" to "python", "rb" to "ruby", "go" to "go", "rs" to "rust",
        "java" to "java", "kt" to "kotlin", "kts" to "kotlin",
        "js" to "javascript", "ts" to "typescript",
        "jsx" to "javascript", "tsx" to "typescript",
        "html" to "html", "css" to "css", "scss" to "scss",
        "xml" to "xml", "yaml" to "yaml", "yml" to "yaml",
        "toml" to "toml", "md" to "markdown",
        "sh" to "bash", "bash" to "bash", "zsh" to "bash",
        "sql" to "sql", "r" to "r", "lua" to "lua",
        "dart" to "dart", "scala" to "scala", "php" to "php"
    )

    fun languageForPath(path: String): String? {
        val ext = path.substringAfterLast('.', "").lowercase()
        if (ext.isEmpty()) {
            val name = path.substringAfterLast('/').lowercase()
            if (name == "dockerfile") return "dockerfile"
            if (name == "makefile") return "makefile"
            return null
        }
        return extensionMap[ext]
    }

    fun highlight(code: String, language: String?): AnnotatedString = buildAnnotatedString {
        val lines = code.split("\n")
        lines.forEachIndexed { lineIndex, line ->
            highlightLine(this, line, language)
            if (lineIndex < lines.size - 1) append("\n")
        }
    }

    private fun highlightLine(builder: AnnotatedString.Builder, line: String, language: String?) {
        var i = 0
        var inString: Char? = null

        while (i < line.length) {
            val char = line[i]

            if (inString != null) {
                val start = i
                i++
                if (char == inString) {
                    inString = null
                } else if (char == '\\' && i < line.length) {
                    i++
                }
                builder.pushStyle(SpanStyle(color = stringColor))
                builder.append(line.substring(start, i))
                builder.pop()
                continue
            }

            if (char == '"' || char == '\'' || char == '`') {
                inString = char
                builder.pushStyle(SpanStyle(color = stringColor))
                builder.append(char.toString())
                builder.pop()
                i++
                continue
            }

            if (i + 1 < line.length && line[i] == '/' && line[i + 1] == '/') {
                builder.pushStyle(SpanStyle(color = commentColor))
                builder.append(line.substring(i))
                builder.pop()
                return
            }

            if (char == '#' && language in hashCommentLanguages) {
                builder.pushStyle(SpanStyle(color = commentColor))
                builder.append(line.substring(i))
                builder.pop()
                return
            }

            if (char.isLetter() || char == '_') {
                val start = i
                while (i < line.length && (line[i].isLetterOrDigit() || line[i] == '_')) i++
                val word = line.substring(start, i)
                when {
                    keywords.contains(word) -> {
                        builder.pushStyle(SpanStyle(color = keywordColor))
                        builder.append(word)
                        builder.pop()
                    }
                    types.contains(word) -> {
                        builder.pushStyle(SpanStyle(color = typeColor))
                        builder.append(word)
                        builder.pop()
                    }
                    else -> builder.append(word)
                }
                continue
            }

            if (char.isDigit()) {
                val start = i
                val isHex = i + 1 < line.length && char == '0' && (line[i + 1] == 'x' || line[i + 1] == 'X')
                val isBin = i + 1 < line.length && char == '0' && (line[i + 1] == 'b' || line[i + 1] == 'B')
                if (isHex || isBin) i += 2
                while (i < line.length) {
                    val c = line[i]
                    if (isHex && (c.isDigit() || c in 'a'..'f' || c in 'A'..'F')) i++
                    else if (isBin && (c == '0' || c == '1')) i++
                    else if (!isHex && !isBin && (c.isDigit() || c == '.')) i++
                    else break
                }
                builder.pushStyle(SpanStyle(color = numberColor))
                builder.append(line.substring(start, i))
                builder.pop()
                continue
            }

            builder.append(char.toString())
            i++
        }
    }
}

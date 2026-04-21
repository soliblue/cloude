import Foundation

enum FilePreviewContentType {
    case image
    case gif
    case video
    case audio
    case pdf
    case markdown
    case json
    case csv
    case html
    case xml
    case code(language: String)
    case text
    case binary

    var hasRenderedView: Bool {
        switch self {
        case .markdown, .json, .html, .csv, .xml: return true
        default: return false
        }
    }

    var isCode: Bool {
        switch self {
        case .code, .text: return true
        default: return false
        }
    }

    var sourceLanguage: String {
        switch self {
        case .markdown: return "markdown"
        case .json: return "json"
        case .html: return "xml"
        case .xml: return "xml"
        case .csv: return "plaintext"
        default: return "plaintext"
        }
    }

    static func detect(for node: FileNodeDTO) -> FilePreviewContentType {
        let ext = URL(fileURLWithPath: node.name).pathExtension.lowercased()
        switch ext {
        case "gif": return .gif
        case "png", "jpg", "jpeg", "webp", "heic", "heif", "bmp", "tiff", "svg":
            return .image
        case "mp4", "mov", "m4v", "avi", "webm", "mkv":
            return .video
        case "wav", "mp3", "m4a", "aac", "ogg", "flac", "caf":
            return .audio
        case "pdf": return .pdf
        case "md", "markdown": return .markdown
        case "json": return .json
        case "csv", "tsv": return .csv
        case "html", "htm": return .html
        case "yaml", "yml": return .code(language: "yaml")
        case "swift": return .code(language: "swift")
        case "py": return .code(language: "python")
        case "js", "mjs", "cjs": return .code(language: "javascript")
        case "ts": return .code(language: "typescript")
        case "tsx": return .code(language: "tsx")
        case "jsx": return .code(language: "jsx")
        case "go": return .code(language: "go")
        case "rs": return .code(language: "rust")
        case "rb": return .code(language: "ruby")
        case "java": return .code(language: "java")
        case "kt", "kts": return .code(language: "kotlin")
        case "c", "h": return .code(language: "c")
        case "cpp", "cc", "cxx", "hpp", "hh": return .code(language: "cpp")
        case "cs": return .code(language: "csharp")
        case "php": return .code(language: "php")
        case "sh", "bash", "zsh": return .code(language: "bash")
        case "css": return .code(language: "css")
        case "scss", "sass": return .code(language: "scss")
        case "xml", "plist": return .xml
        case "toml": return .code(language: "toml")
        case "ini", "conf": return .code(language: "ini")
        case "sql": return .code(language: "sql")
        case "dockerfile": return .code(language: "dockerfile")
        case "txt", "log", "rtf", "": return .text
        default:
            if (node.mimeType ?? "").hasPrefix("text/") { return .text }
            return .binary
        }
    }
}

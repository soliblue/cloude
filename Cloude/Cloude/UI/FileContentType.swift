import Foundation

enum FileContentType {
    case image
    case video
    case audio
    case markdown
    case json
    case yaml
    case csv
    case html
    case code(language: String)
    case markup(language: String)
    case text
    case binary

    var hasRenderedView: Bool {
        switch self {
        case .markdown, .json, .yaml, .csv, .html: return true
        default: return false
        }
    }

    var isTextBased: Bool {
        switch self {
        case .image, .video, .audio, .binary: return false
        default: return true
        }
    }

    var highlightLanguage: String? {
        switch self {
        case .code(let lang), .markup(let lang): return lang
        case .markdown: return "markdown"
        case .json: return "json"
        case .yaml: return "yaml"
        case .csv: return nil
        case .html: return "html"
        default: return nil
        }
    }

    static func from(extension ext: String) -> FileContentType {
        switch ext {
        case "png", "jpg", "jpeg", "gif", "webp", "heic", "svg":
            return .image
        case "mp4", "mov", "m4v", "avi", "webm":
            return .video
        case "wav", "mp3", "m4a", "aac", "ogg", "flac":
            return .audio
        case "md":
            return .markdown
        case "json":
            return .json
        case "yaml", "yml":
            return .yaml
        case "csv", "tsv":
            return .csv
        case "html", "htm":
            return .html
        case "swift":       return .code(language: "swift")
        case "py":          return .code(language: "python")
        case "js":          return .code(language: "javascript")
        case "ts":          return .code(language: "typescript")
        case "jsx":         return .code(language: "javascript")
        case "tsx":         return .code(language: "typescript")
        case "go":          return .code(language: "go")
        case "rs":          return .code(language: "rust")
        case "rb":          return .code(language: "ruby")
        case "java":        return .code(language: "java")
        case "kt":          return .code(language: "kotlin")
        case "c":           return .code(language: "c")
        case "cpp":         return .code(language: "cpp")
        case "h":           return .code(language: "c")
        case "m":           return .code(language: "objectivec")
        case "cs":          return .code(language: "csharp")
        case "php":         return .code(language: "php")
        case "sh", "bash", "zsh":
            return .code(language: "bash")
        case "css":         return .markup(language: "css")
        case "scss":        return .markup(language: "scss")
        case "xml":         return .markup(language: "xml")
        case "toml":        return .markup(language: "ini")
        case "plist":       return .markup(language: "xml")
        case "txt", "log", "rtf":
            return .text
        default:
            return .binary
        }
    }
}

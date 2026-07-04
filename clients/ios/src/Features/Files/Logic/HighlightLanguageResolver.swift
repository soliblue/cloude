import HighlightSwift

enum HighlightLanguageResolver {
    static func resolve(_ language: String) -> HighlightLanguage {
        switch language {
        case "bash": return .bash
        case "cpp": return .cPlusPlus
        case "csharp": return .cSharp
        case "javascript", "jsx": return .javaScript
        case "plaintext": return .plaintext
        case "typescript", "tsx": return .typeScript
        default: return HighlightLanguage(rawValue: language) ?? .plaintext
        }
    }
}

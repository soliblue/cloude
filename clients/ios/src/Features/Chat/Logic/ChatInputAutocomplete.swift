import Foundation

enum ChatInputTrigger: Equatable {
    case slash(String)
    case mention(String)
    case none
}

enum ChatInputAutocomplete {
    static func trigger(in text: String) -> ChatInputTrigger {
        let slash = openToken(in: text, marker: "/")
        let mention = openToken(in: text, marker: "@")
        switch (slash, mention) {
        case let (slash?, mention?):
            return slash.index > mention.index ? .slash(slash.query) : .mention(mention.query)
        case let (slash?, nil):
            return .slash(slash.query)
        case let (nil, mention?):
            return .mention(mention.query)
        default:
            return .none
        }
    }

    static func skillSuggestions(_ skills: [Skill], query: String) -> [ChatInputSuggestion] {
        let needle = query.lowercased()
        return skills
            .filter { needle.isEmpty || $0.name.lowercased().hasPrefix(needle) }
            .map {
                ChatInputSuggestion(
                    kind: .skill, title: $0.name, insertText: "/\($0.name) ",
                    icon: $0.icon ?? "hammer.circle")
            }
    }

    static func agentSuggestions(_ agents: [Agent], query: String) -> [ChatInputSuggestion] {
        let needle = query.lowercased()
        return agents
            .filter { needle.isEmpty || $0.name.lowercased().contains(needle) }
            .sorted { rank($0.name, needle) < rank($1.name, needle) }
            .map {
                ChatInputSuggestion(
                    kind: .agent, title: $0.name, insertText: "@\($0.name) ", icon: "person.fill")
            }
    }

    static func fileSuggestions(_ paths: [String]) -> [ChatInputSuggestion] {
        paths.map {
            ChatInputSuggestion(
                kind: .file, title: ($0 as NSString).lastPathComponent, insertText: "\($0) ",
                icon: "doc")
        }
    }

    static func apply(_ suggestion: ChatInputSuggestion, to text: String) -> String {
        let marker: Character = suggestion.kind == .skill ? "/" : "@"
        if let index = text.lastIndex(of: marker) {
            return String(text[..<index]) + suggestion.insertText
        }
        return text + suggestion.insertText
    }

    private static func openToken(in text: String, marker: Character) -> (index: Int, query: String)? {
        if let index = text.lastIndex(of: marker) {
            let after = text[text.index(after: index)...]
            if after.contains(where: { $0 == " " || $0 == "\n" }) { return nil }
            return (text.distance(from: text.startIndex, to: index), String(after))
        }
        return nil
    }

    private static func rank(_ name: String, _ needle: String) -> Int {
        let lowered = name.lowercased()
        if lowered == needle { return 0 }
        if lowered.hasPrefix(needle) { return 1 }
        return 2
    }
}

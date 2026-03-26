import SwiftUI
import CloudeShared

extension GlobalInputBar {
    var primaryCommands: [SlashCommand] {
        builtInCommands + skills.compactMap { SlashCommand.fromSkill($0).first }
    }

    var allCommandsWithAliases: [SlashCommand] {
        builtInCommands + skills.flatMap { SlashCommand.fromSkill($0) }
    }

    var slashQuery: String? {
        guard let slashIndex = inputText.lastIndex(of: "/") else { return nil }
        let afterSlash = inputText[inputText.index(after: slashIndex)...]
        if afterSlash.contains(where: { $0 == " " || $0 == "\n" }) { return nil }
        return String(afterSlash).lowercased()
    }

    var filteredCommands: [SlashCommand] {
        if inputText.isEmpty {
            return primaryCommands
        }
        guard let query = slashQuery else { return [] }
        if query.isEmpty {
            return primaryCommands
        }
        if let match = allCommandsWithAliases.first(where: { $0.name.lowercased() == query }) {
            return [match]
        }
        return primaryCommands.filter { $0.name.lowercased().hasPrefix(query) }
    }

    var isSlashCommand: Bool {
        inputText.hasPrefix("/")
    }

    var atMentionQuery: String? {
        guard let atIndex = inputText.lastIndex(of: "@") else { return nil }
        let afterAt = inputText[inputText.index(after: atIndex)...]
        if afterAt.contains(where: { $0 == " " || $0 == "\n" }) { return nil }
        return String(afterAt)
    }

    var showFileSuggestions: Bool {
        atMentionQuery != nil && !fileSearchResults.isEmpty
    }

    var showCommandSuggestions: Bool {
        if filteredCommands.isEmpty { return false }
        if inputText.isEmpty && !isInputFocused { return false }
        if inputText.isEmpty && !isRunning { return false }
        return true
    }

    var historySuggestions: [HistoryEntry] {
        guard !showFileSuggestions, !showCommandSuggestions else { return [] }
        return MessageHistory.suggestions(for: inputText)
    }
}

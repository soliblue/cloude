import SwiftUI

struct ChatInputBarSuggestions: View {
    let suggestions: [ChatInputSuggestion]
    let onSelect: (ChatInputSuggestion) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: ThemeTokens.Spacing.s) {
                ForEach(suggestions) { suggestion in
                    Button {
                        onSelect(suggestion)
                    } label: {
                        ChatInputBarSuggestionPill(suggestion: suggestion)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .scrollClipDisabled()
    }
}

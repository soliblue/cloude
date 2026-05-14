import SwiftUI

struct WindowsSidebarRow: View {
    let symbol: String
    let title: String
    let isFocused: Bool
    var isStreaming: Bool = false
    var isUnread: Bool = false
    var endpointName: String? = nil
    var path: String? = nil
    @Environment(\.appAccent) private var appAccent
    @State private var pulse: Bool = false

    var body: some View {
        let highlight = isStreaming || isUnread
        HStack(spacing: ThemeTokens.Spacing.m) {
            Image(systemName: symbol)
                .appFont(size: ThemeTokens.Text.l, weight: .medium)
                .foregroundColor(highlight ? appAccent.color : (isFocused ? .primary : .secondary))
                .frame(width: ThemeTokens.Size.m)
            VStack(alignment: .leading, spacing: ThemeTokens.Spacing.xs) {
                Text(title)
                    .appFont(size: ThemeTokens.Text.l, weight: (isFocused || highlight) ? .medium : .regular)
                    .foregroundColor(highlight ? appAccent.color : .primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                if endpointName != nil || path != nil {
                    HStack(spacing: ThemeTokens.Spacing.xs) {
                        if let endpointName {
                            Text(endpointName)
                                .lineLimit(1)
                                .truncationMode(.tail)
                                .layoutPriority(1)
                        }
                        if endpointName != nil, path != nil {
                            Text("·")
                        }
                        if let path {
                            Text(path)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                    }
                    .appFont(size: ThemeTokens.Text.s, weight: .regular)
                    .foregroundColor(.secondary)
                }
            }
        }
        .opacity(isStreaming && pulse ? 0.4 : 1.0)
        .animation(isStreaming ? .easeInOut(duration: 0.9).repeatForever(autoreverses: true) : .default, value: pulse)
        .onAppear { if isStreaming { pulse = true } }
        .onChange(of: isStreaming) { _, streaming in
            pulse = streaming
        }
    }
}

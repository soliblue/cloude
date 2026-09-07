import SwiftUI

struct WindowsSidebarRow: View {
    let symbol: String
    let title: String
    let isFocused: Bool
    var isStreaming: Bool = false
    var isUnread: Bool = false
    var needsAttention: Bool = false
    var endpointName: String? = nil
    var path: String? = nil
    @Environment(\.appAccent) private var appAccent

    @ScaledMetric(relativeTo: .body) private var iconColumnWidth = ThemeTokens.Size.m

    var body: some View {
        let highlight = isStreaming || isUnread || needsAttention
        HStack(spacing: ThemeTokens.Spacing.m) {
            Image(systemName: symbol)
                .appFont(size: ThemeTokens.Text.l, weight: .medium)
                .foregroundColor(highlight ? appAccent.color : (isFocused ? .primary : ThemeColor.secondary))
                .fixedSize()
                .frame(minWidth: iconColumnWidth)
                .accessibilityHidden(true)
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
                    .foregroundColor(ThemeColor.secondary)
                }
            }
            Spacer(minLength: 0)
            if isStreaming {
                ProgressView()
                    .controlSize(.mini)
                    .accessibilityLabel("Working")
            } else if isUnread || needsAttention {
                Circle()
                    .fill(appAccent.color)
                    .frame(width: 7, height: 7)
                    .accessibilityLabel("Unread")
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(
            [
                needsAttention ? "Needs attention" : isStreaming ? "Working" : isUnread ? "Unread" : nil,
                endpointName, path,
            ]
            .compactMap { $0 }.joined(separator: ", ")
        )
        .accessibilityAddTraits(isFocused ? .isSelected : [])
    }
}

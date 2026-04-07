import SwiftUI
import CloudeShared

struct ToolCallLabel: View {
    let meta: ToolMetadata

    init(name: String, input: String?) {
        self.meta = ToolMetadata(name: name, input: input)
    }

    var body: some View {
        HStack(spacing: DS.Spacing.xs) {
            Image(systemName: meta.icon)
                .font(.system(size: DS.Text.s, weight: .semibold))
            Text(meta.displayName)
                .font(.system(size: DS.Text.s, weight: .semibold, design: .monospaced))
            if let detail = meta.detail {
                Text(detail)
                    .font(.system(size: DS.Text.s, design: .monospaced))
                    .opacity(DS.Opacity.l)
            }
        }
        .foregroundColor(meta.color)
    }
}

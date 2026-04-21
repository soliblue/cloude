import SwiftUI

struct FilePreviewJSONRow: View {
    let key: String?
    let value: Any
    @State private var isExpanded = true

    var body: some View {
        VStack(alignment: .leading, spacing: ThemeTokens.Spacing.xs) {
            if let dict = value as? [String: Any] {
                Button {
                    isExpanded.toggle()
                } label: {
                    header(symbol: "{\(dict.count)}")
                }
                .buttonStyle(.plain)
                if isExpanded {
                    ForEach(Array(dict.keys).sorted(), id: \.self) { k in
                        FilePreviewJSONRow(key: k, value: dict[k] ?? NSNull())
                            .padding(.leading, ThemeTokens.Spacing.m)
                    }
                }
            } else if let array = value as? [Any] {
                Button {
                    isExpanded.toggle()
                } label: {
                    header(symbol: "[\(array.count)]")
                }
                .buttonStyle(.plain)
                if isExpanded {
                    ForEach(array.indices, id: \.self) { i in
                        FilePreviewJSONRow(key: String(i), value: array[i])
                            .padding(.leading, ThemeTokens.Spacing.m)
                    }
                }
            } else {
                HStack(spacing: ThemeTokens.Spacing.xs) {
                    if let key {
                        Text("\(key):")
                            .appFont(size: ThemeTokens.Text.m, design: .monospaced)
                            .foregroundColor(.secondary)
                    }
                    Text(leafText(value))
                        .appFont(size: ThemeTokens.Text.m, design: .monospaced)
                        .foregroundColor(leafColor(value))
                        .textSelection(.enabled)
                }
            }
        }
    }

    private func header(symbol: String) -> some View {
        HStack(spacing: ThemeTokens.Spacing.xs) {
            Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                .appFont(size: ThemeTokens.Icon.s)
                .foregroundColor(.secondary)
            if let key {
                Text("\(key):")
                    .appFont(size: ThemeTokens.Text.m, design: .monospaced)
                    .foregroundColor(.secondary)
            }
            Text(symbol)
                .appFont(size: ThemeTokens.Text.m, design: .monospaced)
                .foregroundColor(.secondary)
        }
    }

    private func leafText(_ value: Any) -> String {
        if let string = value as? String { return "\"\(string)\"" }
        if value is NSNull { return "null" }
        if let bool = value as? Bool { return bool ? "true" : "false" }
        return "\(value)"
    }

    private func leafColor(_ value: Any) -> Color {
        if value is String { return ThemeColor.green }
        if value is NSNull { return .secondary }
        if value is Bool { return ThemeColor.orange }
        if value is NSNumber { return ThemeColor.blue }
        return .primary
    }
}

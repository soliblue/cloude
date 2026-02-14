import SwiftUI

struct JSONTreeView: View {
    let value: Any
    let label: String
    @State private var expanded = true

    var body: some View {
        JSONNodeView(key: label, value: value, depth: 0, startExpanded: true)
    }
}

private struct JSONNodeView: View {
    let key: String?
    let value: Any
    let depth: Int
    var startExpanded: Bool = false
    @State private var expanded: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            switch categorize(value) {
            case .dictionary(let dict):
                collapsibleNode(
                    count: dict.count,
                    openBrace: "{",
                    closeBrace: "}"
                ) {
                    ForEach(dict.keys.sorted(), id: \.self) { k in
                        JSONNodeView(key: k, value: dict[k]!, depth: depth + 1)
                    }
                }
            case .array(let arr):
                collapsibleNode(
                    count: arr.count,
                    openBrace: "[",
                    closeBrace: "]"
                ) {
                    ForEach(Array(arr.enumerated()), id: \.offset) { i, item in
                        JSONNodeView(key: "\(i)", value: item, depth: depth + 1)
                    }
                }
            case .string(let s):
                leafRow {
                    Text("\"\(s)\"")
                        .foregroundColor(.green)
                        .textSelection(.enabled)
                }
            case .number(let n):
                leafRow {
                    Text(n.description)
                        .foregroundColor(.orange)
                        .textSelection(.enabled)
                }
            case .bool(let b):
                leafRow {
                    Text(b ? "true" : "false")
                        .foregroundColor(.blue)
                        .textSelection(.enabled)
                }
            case .null:
                leafRow {
                    Text("null")
                        .foregroundColor(.secondary)
                        .textSelection(.enabled)
                }
            }
        }
        .onAppear {
            if startExpanded { expanded = true }
        }
    }

    @ViewBuilder
    private func collapsibleNode<Content: View>(
        count: Int,
        openBrace: String,
        closeBrace: String,
        @ViewBuilder children: () -> Content
    ) -> some View {
        Button(action: { expanded.toggle() }) {
            HStack(spacing: 4) {
                Image(systemName: expanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .frame(width: 14)
                if let key = key, depth > 0 {
                    Text("\(key):")
                        .foregroundColor(.primary)
                }
                if expanded {
                    Text(openBrace)
                        .foregroundColor(.secondary)
                } else {
                    Text("\(openBrace) \(count) item\(count == 1 ? "" : "s") \(closeBrace)")
                        .foregroundColor(.secondary)
                }
            }
            .font(.system(size: 13, design: .monospaced))
        }
        .buttonStyle(.plain)
        .padding(.vertical, 3)

        if expanded {
            VStack(alignment: .leading, spacing: 0) {
                children()
            }
            .padding(.leading, 16)

            HStack(spacing: 4) {
                Spacer().frame(width: 14)
                Text(closeBrace)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 1)
        }
    }

    @ViewBuilder
    private func leafRow<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 4) {
            Spacer().frame(width: 14)
            if let key = key, depth > 0 {
                Text("\(key):")
                    .foregroundColor(.primary)
            }
            content()
        }
        .font(.system(size: 13, design: .monospaced))
        .padding(.vertical, 3)
    }

    private enum JSONCategory {
        case dictionary([String: Any])
        case array([Any])
        case string(String)
        case number(NSNumber)
        case bool(Bool)
        case null
    }

    private func categorize(_ value: Any) -> JSONCategory {
        if value is NSNull { return .null }
        if let dict = value as? [String: Any] { return .dictionary(dict) }
        if let arr = value as? [Any] { return .array(arr) }
        if let num = value as? NSNumber {
            if CFBooleanGetTypeID() == CFGetTypeID(num) {
                return .bool(num.boolValue)
            }
            return .number(num)
        }
        if let s = value as? String { return .string(s) }
        return .null
    }
}

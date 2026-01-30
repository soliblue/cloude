//
//  ChatView+Input.swift
//  Cloude
//

import SwiftUI

struct ToolCallRow: View {
    let name: String
    let input: String?
    @State private var isExpanded = false

    var body: some View {
        Button(action: { isExpanded.toggle() }) {
            HStack(spacing: 6) {
                Image(systemName: iconName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(width: 16)

                Text(displayText)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(.secondary)
                    .lineLimit(isExpanded ? nil : 1)
                    .truncationMode(.middle)

                Spacer()

                if input != nil && !isExpanded {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10))
                        .foregroundColor(Color(.tertiaryLabel))
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(.tertiarySystemBackground))
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }

    private var iconName: String {
        switch name {
        case "Bash": return "terminal"
        case "Read": return "doc.text"
        case "Write": return "doc.badge.plus"
        case "Edit": return "pencil"
        case "Glob": return "folder.badge.questionmark"
        case "Grep": return "magnifyingglass"
        case "Task": return "arrow.trianglehead.branch"
        case "WebFetch": return "globe"
        case "WebSearch": return "magnifyingglass.circle"
        default: return "bolt"
        }
    }

    private var displayText: String {
        guard let input = input else { return name }
        switch name {
        case "Bash":
            return input
        case "Read", "Write", "Edit":
            return isExpanded ? input : (input as NSString).lastPathComponent
        case "Task":
            return input
        default:
            return "\(name): \(input)"
        }
    }
}

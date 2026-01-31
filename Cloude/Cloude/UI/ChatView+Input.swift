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
                ToolCallLabel(name: name, input: isExpanded ? nil : input)

                if isExpanded, let input = input {
                    Text(input)
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(toolCallColor(for: name, input: input))
                        .opacity(0.85)
                }

                Spacer()

                if input != nil && !isExpanded {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10))
                        .foregroundColor(Color(.tertiaryLabel))
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(toolCallColor(for: name, input: input).opacity(0.08))
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }
}

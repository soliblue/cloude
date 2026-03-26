// ToolDetailSheet.swift

import SwiftUI
import CloudeShared

struct ToolDetailSheet: View {
    let toolCall: ToolCall
    var children: [ToolCall] = []
    @Environment(\.dismiss) var dismiss
    @Environment(\.openURL) var openURL
    @State var outputExpanded = false

    let outputPreviewLineCount = 15

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    statusBanner

                    if let todos = todoItems {
                        todoSection(todos)
                    } else if !chainedCommands.isEmpty {
                        chainSection
                    } else if let input = toolCall.input, !input.isEmpty,
                              toolCall.editInfo == nil {
                        inputSection(input)
                    }

                    if let path = toolCall.filePath {
                        fileSection(path)
                    }

                    if let editInfo = toolCall.editInfo {
                        editDiffSection(editInfo)
                    } else if toolCall.name == "Read", let output = toolCall.resultOutput, !output.isEmpty {
                        readOutputSection(output)
                    } else if toolCall.name == "Agent", let output = toolCall.resultOutput, !output.isEmpty {
                        markdownOutputSection(output)
                    } else if let output = displayedOutput {
                        outputSection(output)
                    }

                    if !children.isEmpty {
                        childrenSection
                    }
                }
                .padding()
            }
            .background(Color.themeBackground)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 5) {
                        Image(systemName: iconName)
                            .font(.system(size: 12, weight: .semibold))
                        Text(toolTitle)
                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                            .lineLimit(1)
                    }
                    .foregroundColor(toolCallColor(for: toolCall.name, input: toolCall.input))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(toolCallColor(for: toolCall.name, input: toolCall.input).opacity(0.12))
                    .clipShape(Capsule())
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: DS.Icon.s, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.themeBackground)
    }

    @ViewBuilder
    var statusBanner: some View {
        if toolCall.state == .executing {
            HStack(spacing: 8) {
                ProgressView()
                    .scaleEffect(0.8)
                Text("Executing")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.themeSecondary.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}

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
                VStack(alignment: .leading, spacing: DS.Spacing.l) {
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
                    HStack(spacing: DS.Spacing.xs) {
                        Image(systemName: iconName)
                            .font(.system(size: DS.Text.m, weight: .semibold))
                        Text(toolTitle)
                            .font(.system(size: DS.Text.m, weight: .semibold, design: .monospaced))
                            .lineLimit(1)
                    }
                    .foregroundColor(toolCallColor(for: toolCall.name, input: toolCall.input))
                    .padding(.horizontal, DS.Spacing.m)
                    .padding(.vertical, DS.Spacing.s)
                    .background(toolCallColor(for: toolCall.name, input: toolCall.input).opacity(DS.Opacity.s))
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
            HStack(spacing: DS.Spacing.s) {
                ProgressView()
                    .scaleEffect(DS.Scale.m)
                Text("Executing")
                    .font(.system(size: DS.Text.m, weight: .medium))
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(DS.Spacing.m)
            .background(Color.themeSecondary.opacity(DS.Opacity.m))
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.m))
        }
    }
}

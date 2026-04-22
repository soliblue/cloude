import HighlightSwift
import SwiftUI

struct ChatViewMessageListRowToolPillSheet: View {
    let session: Session
    let toolCall: ChatToolCall
    @Environment(\.dismiss) private var dismiss
    @Environment(\.filePreviewPresenter) private var presenter
    @Environment(\.theme) private var theme

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: ThemeTokens.Spacing.l) {
                    if toolCall.state == .pending { statusBanner }
                    primaryContent
                    if let result = toolCall.result, !result.isEmpty, !handlesOutputInline {
                        ChatViewMessageListRowToolPillSheetOutput(
                            text: result, isError: toolCall.state == .failed
                        )
                    }
                }
                .padding(ThemeTokens.Spacing.m)
            }
            .background(theme.palette.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) { titlePill }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .appFont(size: ThemeTokens.Text.m, weight: .medium)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .themedNavChrome()
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(theme.palette.background)
    }

    private var titlePill: some View {
        HStack(spacing: ThemeTokens.Spacing.xs) {
            Image(systemName: toolCall.symbol)
                .appFont(size: ThemeTokens.Text.m, weight: .semibold)
            Text(toolCall.name)
                .appFont(size: ThemeTokens.Text.m, weight: .semibold, design: .monospaced)
                .lineLimit(1)
        }
        .foregroundColor(toolCall.kind.color)
        .padding(.horizontal, ThemeTokens.Spacing.m)
        .padding(.vertical, ThemeTokens.Spacing.s)
        .background(toolCall.kind.color.opacity(ThemeTokens.Opacity.s))
        .clipShape(Capsule())
    }

    private var statusBanner: some View {
        HStack(spacing: ThemeTokens.Spacing.s) {
            ProgressView().controlSize(.small)
            Text("Executing")
                .appFont(size: ThemeTokens.Text.m, weight: .medium)
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(ThemeTokens.Spacing.m)
        .background(theme.palette.surface)
        .clipShape(RoundedRectangle(cornerRadius: ThemeTokens.Radius.m))
    }

    @ViewBuilder
    private var primaryContent: some View {
        if let todos = toolCall.todoItems {
            ChatViewMessageListRowToolPillSheetTodoList(items: todos)
        } else if let edit = toolCall.editStrings {
            if let path = toolCall.filePath { fileSection(path) }
            ChatViewMessageListRowToolPillSheetEditDiff(
                oldText: edit.old, newText: edit.new, language: language
            )
        } else if toolCall.kind == .read, let path = toolCall.filePath {
            fileSection(path)
            if let result = toolCall.result, !result.isEmpty {
                ChatViewMessageListRowToolPillSheetReadOutput(text: result, language: language)
            }
        } else {
            inputSection
        }
    }

    @ViewBuilder
    private var inputSection: some View {
        if !toolCall.inputSummary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            ChatViewMessageListRowToolPillSheetSection(title: "Input", icon: "arrow.right.circle") {
                CodeText(toolCall.inputJSON)
                    .appFont(size: ThemeTokens.Text.s, design: .monospaced)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
        }
    }

    private func fileSection(_ path: String) -> some View {
        VStack(alignment: .leading, spacing: ThemeTokens.Spacing.s) {
            Label("File", systemImage: "doc")
                .appFont(size: ThemeTokens.Text.m, weight: .semibold)
                .foregroundColor(.secondary)
            Button {
                presenter.open(session: session, path: path)
                dismiss()
            } label: {
                HStack(spacing: ThemeTokens.Spacing.s) {
                    Image(systemName: "doc.text")
                        .foregroundColor(toolCall.kind.color)
                    Text((path as NSString).lastPathComponent)
                        .appFont(size: ThemeTokens.Text.m, design: .monospaced)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .appFont(size: ThemeTokens.Text.s)
                        .foregroundColor(.secondary)
                }
                .padding(ThemeTokens.Spacing.m)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(theme.palette.surface)
                .clipShape(RoundedRectangle(cornerRadius: ThemeTokens.Radius.m))
                .contentShape(RoundedRectangle(cornerRadius: ThemeTokens.Radius.m))
            }
            .buttonStyle(.plain)
        }
    }

    private var handlesOutputInline: Bool {
        toolCall.kind == .read || toolCall.todoItems != nil
    }

    private var language: String {
        guard let path = toolCall.filePath else { return "plaintext" }
        return FilePreviewContentType.detect(path: path).sourceLanguage
    }
}

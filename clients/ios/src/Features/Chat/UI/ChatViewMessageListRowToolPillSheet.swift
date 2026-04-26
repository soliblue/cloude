import HighlightSwift
import SwiftData
import SwiftUI

struct ChatViewMessageListRowToolPillSheet: View {
    let session: Session
    let toolCall: ChatToolCall
    @Environment(\.dismiss) private var dismiss
    @Environment(\.filePreviewPresenter) private var presenter
    @Environment(\.theme) private var theme
    @Query private var children: [ChatToolCall]
    @State private var shimmerPhase: CGFloat = -1

    init(session: Session, toolCall: ChatToolCall) {
        self.session = session
        self.toolCall = toolCall
        let parentId = toolCall.id
        _children = Query(
            filter: #Predicate<ChatToolCall> { $0.parentToolUseId == parentId },
            sort: \ChatToolCall.order
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: ThemeTokens.Spacing.l) {
                    primaryContent
                    if let result = toolCall.result, !result.isEmpty, !handlesOutputInline {
                        ChatViewMessageListRowToolPillSheetOutput(
                            text: result, isError: toolCall.state == .failed
                        )
                    }
                    if !children.isEmpty { childrenSection }
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
        let tint = toolCall.kind.color
        return HStack(spacing: ThemeTokens.Spacing.xs) {
            Image(systemName: toolCall.symbol)
                .appFont(size: ThemeTokens.Text.m, weight: .semibold)
            Text(toolCall.displayName)
                .appFont(size: ThemeTokens.Text.m, weight: .semibold, design: .monospaced)
                .lineLimit(1)
        }
        .foregroundColor(tint)
        .padding(.horizontal, ThemeTokens.Spacing.m)
        .padding(.vertical, ThemeTokens.Spacing.s)
        .background(tint.opacity(ThemeTokens.Opacity.s))
        .clipShape(Capsule())
        .overlay {
            if toolCall.state == .pending {
                ChatViewMessageListRowToolPillListRowShimmer(phase: shimmerPhase, tint: tint)
                    .clipShape(Capsule())
                    .transition(.opacity)
            }
        }
        .onAppear {
            if toolCall.state == .pending {
                withAnimation(.easeInOut(duration: 2.13).repeatForever(autoreverses: true)) {
                    shimmerPhase = 1.5
                }
            }
        }
        .onChange(of: toolCall.state) { _, newState in
            if newState != .pending {
                withAnimation(.easeOut(duration: 0.2)) { shimmerPhase = -1 }
            }
        }
    }

    @ViewBuilder
    private var primaryContent: some View {
        if let todos = toolCall.todoItems {
            ChatViewMessageListRowToolPillSheetTodoList(items: todos)
        } else if let edit = toolCall.editStrings {
            if let path = toolCall.filePath {
                ChatViewMessageListRowToolPillSheetFileRow(
                    session: session, toolCall: toolCall, path: path)
            }
            ChatViewMessageListRowToolPillSheetEditDiff(
                oldText: edit.old, newText: edit.new, language: language
            )
        } else {
            switch toolCall.kind {
            case .read:
                if let path = toolCall.filePath {
                    ChatViewMessageListRowToolPillSheetFileRow(
                        session: session, toolCall: toolCall, path: path)
                }
                if let result = toolCall.result, !result.isEmpty {
                    ChatViewMessageListRowToolPillSheetReadOutput(text: result, language: language)
                }
            case .write:
                ChatViewMessageListRowToolPillSheetWrite(session: session, toolCall: toolCall)
            case .bash:
                ChatViewMessageListRowToolPillSheetBash(toolCall: toolCall)
            case .grep:
                ChatViewMessageListRowToolPillSheetGrep(toolCall: toolCall)
            case .glob:
                ChatViewMessageListRowToolPillSheetGlob(toolCall: toolCall)
            case .web:
                ChatViewMessageListRowToolPillSheetWeb(toolCall: toolCall)
            case .task:
                ChatViewMessageListRowToolPillSheetAgent(toolCall: toolCall)
            default:
                inputSection
            }
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

    private var childrenSection: some View {
        VStack(alignment: .leading, spacing: ThemeTokens.Spacing.s) {
            Label("Tools (\(children.count))", systemImage: "square.stack")
                .appFont(size: ThemeTokens.Text.m, weight: .semibold)
                .foregroundColor(.secondary)
            VStack(spacing: 0) {
                ForEach(Array(children.enumerated()), id: \.element.id) { index, child in
                    HStack(spacing: ThemeTokens.Spacing.m) {
                        Image(systemName: child.symbol)
                            .appFont(size: ThemeTokens.Text.m, weight: .semibold)
                            .foregroundColor(child.kind.color)
                        Text(child.name)
                            .appFont(size: ThemeTokens.Text.m, weight: .semibold, design: .monospaced)
                        Text(child.shortLabel)
                            .appFont(size: ThemeTokens.Text.s, design: .monospaced)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer()
                        if child.state == .pending {
                            ProgressView().controlSize(.small)
                        } else if child.state == .failed {
                            Image(systemName: "xmark")
                                .appFont(size: ThemeTokens.Text.s, weight: .bold)
                                .foregroundColor(.red)
                        } else {
                            Image(systemName: "checkmark")
                                .appFont(size: ThemeTokens.Text.s, weight: .bold)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, ThemeTokens.Spacing.s)
                    .padding(.horizontal, ThemeTokens.Spacing.m)
                    if index < children.count - 1 {
                        Divider().padding(.leading, ThemeTokens.Spacing.m)
                    }
                }
            }
            .background(theme.palette.surface)
            .clipShape(RoundedRectangle(cornerRadius: ThemeTokens.Radius.m))
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

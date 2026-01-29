//
//  ProjectChatView+Components.swift
//  Cloude
//
//  Components for ProjectChatView
//

import SwiftUI
import UIKit

struct PaneHeaderView: View {
    let project: Project?
    let conversation: Conversation?
    let onSelectConversation: (() -> Void)?

    var body: some View {
        Button(action: { onSelectConversation?() }) {
            HStack {
                if let conv = conversation {
                    Text(conv.name)
                        .font(.caption)
                        .fontWeight(.medium)
                        .lineLimit(1)
                    if let proj = project {
                        Text("• \(proj.name)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                } else {
                    Text("Select conversation...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color(.secondarySystemBackground))
        }
        .buttonStyle(.plain)
    }
}

struct ProjectChatMessageList: View {
    let messages: [ChatMessage]
    let currentOutput: String
    let currentToolCalls: [ToolCall]
    let currentRunStats: (durationMs: Int, costUsd: Double)?
    @Binding var scrollProxy: ScrollViewProxy?
    let agentState: AgentState

    var body: some View {
        GeometryReader { geometry in
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(messages) { message in
                            MessageBubble(message: message)
                                .id(message.id)
                        }

                        if !currentToolCalls.isEmpty || !currentOutput.isEmpty || currentRunStats != nil {
                            streamingView
                        }

                        Spacer()
                            .frame(height: geometry.size.height - 100)
                            .id("bottomSpacer")
                    }
                }
                .scrollDismissesKeyboard(.interactively)
                .onTapGesture {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
                .onAppear { scrollProxy = proxy }
                .onChange(of: agentState) { old, new in
                    if old == .idle && new == .running {
                        scrollToBottom()
                    }
                }
            }
        }
    }

    private var streamingView: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !currentToolCalls.isEmpty {
                ToolCallsSection(toolCalls: currentToolCalls)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
            }
            if !currentOutput.isEmpty {
                StreamingOutput(text: currentOutput)
            }
            if let stats = currentRunStats {
                RunStatsView(durationMs: stats.durationMs, costUsd: stats.costUsd)
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
            }
        }
        .id("streaming")
    }

    private func scrollToBottom() {
        withAnimation(.easeOut(duration: 0.2)) {
            if !currentOutput.isEmpty {
                scrollProxy?.scrollTo("streaming", anchor: .bottom)
            } else if let last = messages.last {
                scrollProxy?.scrollTo(last.id, anchor: .top)
            }
        }
    }
}

struct ProjectChatInputArea: View {
    @Binding var inputText: String
    let hasClipboardContent: Bool
    let agentState: AgentState
    let isConnected: Bool
    var isCompact: Bool = false
    let onSend: () -> Void
    let onAbort: () -> Void

    var body: some View {
        HStack(alignment: .bottom, spacing: isCompact ? 8 : 12) {
            if !isCompact {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                    .padding(.bottom, 8)
            }

            TextField("Message...", text: $inputText, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...(isCompact ? 3 : 6))
                .onSubmit { onSend() }

            if isCompact {
                HStack(spacing: 8) {
                    if hasClipboardContent && inputText.isEmpty {
                        Button(action: pasteFromClipboard) {
                            Image(systemName: "clipboard")
                                .foregroundColor(.secondary)
                        }
                    }
                    if agentState == .running {
                        Button(action: onAbort) {
                            Image(systemName: "stop.circle.fill")
                                .foregroundColor(.orange)
                        }
                    } else {
                        Button(action: onSend) {
                            Image(systemName: "paperplane")
                                .foregroundColor(inputText.isEmpty ? .secondary : .accentColor)
                        }
                        .disabled(inputText.isEmpty)
                    }
                }
            } else {
                InputButtons(
                    inputText: $inputText,
                    hasClipboardContent: hasClipboardContent,
                    agentState: agentState,
                    onPaste: pasteFromClipboard,
                    onClear: { inputText = "" },
                    onAbort: onAbort,
                    onSend: onSend
                )
            }
        }
        .padding(.horizontal, isCompact ? 12 : 16)
        .padding(.top, isCompact ? 10 : 12)
        .padding(.bottom, isCompact ? 10 : 16)
        .background(Color(.systemBackground))
    }

    private var statusColor: Color {
        if isConnected {
            return agentState == .running ? .orange : .green
        }
        return .red
    }

    private func pasteFromClipboard() {
        if let text = UIPasteboard.general.string {
            inputText = text
        }
    }
}

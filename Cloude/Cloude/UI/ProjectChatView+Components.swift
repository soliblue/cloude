//
//  ProjectChatView+Components.swift
//  Cloude
//
//  Components for ProjectChatView
//

import SwiftUI

struct WindowHeaderView: View {
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
    let conversationId: UUID?
    var isKeyboardVisible: Bool = false
    var onRefresh: (() async -> Void)?
    var onInteraction: (() -> Void)?

    @State private var hasScrolledToStreaming = false
    @State private var lastUserMessageCount = 0
    @State private var showScrollToBottom = false

    private var bottomId: String {
        "bottom-\(conversationId?.uuidString ?? "none")"
    }

    private var streamingId: String {
        "streaming-\(conversationId?.uuidString ?? "none")"
    }

    var body: some View {
        let userMessageCount = messages.filter { $0.isUser }.count

        ZStack(alignment: .bottomTrailing) {
            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(messages) { message in
                            MessageBubble(message: message)
                                .id(message.id)
                        }

                        if !currentToolCalls.isEmpty || !currentOutput.isEmpty || currentRunStats != nil {
                            streamingView
                        }

                        Color.clear
                            .frame(height: 1)
                            .id(bottomId)
                            .onAppear { showScrollToBottom = false }
                            .onDisappear { showScrollToBottom = true }
                    }
                    .padding(.bottom, 16)
                }
                .refreshable {
                    await onRefresh?()
                }
                .scrollDismissesKeyboard(.immediately)
                .onTapGesture {
                    onInteraction?()
                }
                .simultaneousGesture(
                    DragGesture(minimumDistance: 5)
                        .onChanged { _ in onInteraction?() }
                )
                .onAppear {
                    scrollProxy = proxy
                    lastUserMessageCount = userMessageCount
                }
                .onChange(of: userMessageCount) { oldCount, newCount in
                    if newCount > oldCount, let lastUserMessage = messages.last(where: { $0.isUser }) {
                        scrollToMessage(lastUserMessage.id, keyboardVisible: isKeyboardVisible)
                    }
                    lastUserMessageCount = newCount
                }
                .onChange(of: isKeyboardVisible) { _, visible in
                    if visible, let lastUserMessage = messages.last(where: { $0.isUser }) {
                        scrollToMessage(lastUserMessage.id, keyboardVisible: true)
                    }
                }
                .onChange(of: currentOutput) { oldValue, newValue in
                    if oldValue.isEmpty && !newValue.isEmpty && !hasScrolledToStreaming {
                        hasScrolledToStreaming = true
                        withAnimation(.easeOut(duration: 0.2)) {
                            scrollProxy?.scrollTo(streamingId, anchor: .top)
                        }
                    }
                    if newValue.isEmpty {
                        hasScrolledToStreaming = false
                    }
                }
            }

            if showScrollToBottom {
                Image(systemName: "arrow.down")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)
                    .frame(width: 44, height: 44)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
                    .contentShape(Circle())
                    .onTapGesture {
                        withAnimation(.easeOut(duration: 0.2)) {
                            scrollProxy?.scrollTo(bottomId, anchor: .bottom)
                        }
                    }
                    .padding(.trailing, 16)
                    .padding(.bottom, 8)
                    .transition(.opacity.combined(with: .scale(scale: 0.8)))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showScrollToBottom)
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
        .id(streamingId)
    }

    private func scrollToMessage(_ id: UUID, keyboardVisible: Bool = false) {
        withAnimation(.easeOut(duration: 0.2)) {
            scrollProxy?.scrollTo(id, anchor: keyboardVisible ? .bottom : .top)
        }
    }
}

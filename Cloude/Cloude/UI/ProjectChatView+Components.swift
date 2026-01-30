//
//  ProjectChatView+Components.swift
//  Cloude
//
//  Components for ProjectChatView
//

import SwiftUI
import UIKit
import PhotosUI

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
    var onRefresh: (() async -> Void)?
    var onInteraction: (() -> Void)?

    @State private var hasScrolledToStreaming = false
    @State private var lastUserMessageCount = 0

    var body: some View {
        let userMessageCount = messages.filter { $0.isUser }.count

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
                    scrollToMessage(lastUserMessage.id)
                }
                lastUserMessageCount = newCount
            }
            .onChange(of: currentOutput) { oldValue, newValue in
                if oldValue.isEmpty && !newValue.isEmpty && !hasScrolledToStreaming {
                    hasScrolledToStreaming = true
                    withAnimation(.easeOut(duration: 0.2)) {
                        scrollProxy?.scrollTo("streaming", anchor: .top)
                    }
                }
                if newValue.isEmpty {
                    hasScrolledToStreaming = false
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

    private func scrollToMessage(_ id: UUID) {
        withAnimation(.easeOut(duration: 0.2)) {
            scrollProxy?.scrollTo(id, anchor: .top)
        }
    }
}

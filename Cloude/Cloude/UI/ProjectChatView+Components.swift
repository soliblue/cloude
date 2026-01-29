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

    var body: some View {
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
            .onAppear { scrollProxy = proxy }
            .onChange(of: messages.count) { oldCount, newCount in
                if newCount > oldCount, let lastUserMessage = messages.last(where: { $0.isUser }) {
                    scrollToMessage(lastUserMessage.id)
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

struct ProjectChatInputArea: View {
    @Binding var inputText: String
    @Binding var selectedImageData: Data?
    let hasClipboardContent: Bool
    let agentState: AgentState
    let isConnected: Bool
    var isCompact: Bool = false
    var pendingCount: Int = 0
    let onSend: () -> Void
    var onInputFocus: (() -> Void)?

    @State private var selectedItem: PhotosPickerItem?
    @FocusState private var isInputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            if pendingCount > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.caption2)
                    Text("\(pendingCount) message\(pendingCount == 1 ? "" : "s") queued")
                        .font(.caption2)
                }
                .foregroundColor(.secondary)
                .padding(.vertical, 4)
            }

            if let imageData = selectedImageData, let uiImage = UIImage(data: imageData) {
                HStack {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 60)
                        .cornerRadius(8)
                    Button(action: { selectedImageData = nil }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding(.horizontal, isCompact ? 12 : 16)
                .padding(.top, 8)
            }

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
                    .focused($isInputFocused)
                    .onSubmit { onSend() }

                if isCompact {
                    HStack(spacing: 8) {
                        PhotosPicker(selection: $selectedItem, matching: .images) {
                            Image(systemName: "photo")
                                .foregroundColor(.secondary)
                        }
                        if hasClipboardContent && inputText.isEmpty {
                            Button(action: pasteFromClipboard) {
                                Image(systemName: "clipboard")
                                    .foregroundColor(.secondary)
                            }
                        }
                        Button(action: onSend) {
                            Image(systemName: "paperplane")
                                .foregroundColor(canSend ? .accentColor : .secondary)
                        }
                        .disabled(!canSend)
                    }
                } else {
                    HStack(spacing: 8) {
                        PhotosPicker(selection: $selectedItem, matching: .images) {
                            Image(systemName: "photo")
                                .foregroundColor(.secondary)
                        }
                        InputButtons(
                            inputText: $inputText,
                            hasClipboardContent: hasClipboardContent,
                            agentState: agentState,
                            onPaste: pasteFromClipboard,
                            onClear: { inputText = ""; selectedImageData = nil },
                            onSend: onSend
                        )
                    }
                }
            }
            .padding(.horizontal, isCompact ? 12 : 16)
            .padding(.top, isCompact ? 10 : 12)
            .padding(.bottom, isCompact ? 10 : 16)
        }
        .background(Color(.systemBackground))
        .onChange(of: selectedItem) { _, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self) {
                    selectedImageData = data
                }
            }
        }
        .onChange(of: isInputFocused) { _, focused in
            if focused { onInputFocus?() }
        }
    }

    private var canSend: Bool {
        !inputText.isEmpty || selectedImageData != nil
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

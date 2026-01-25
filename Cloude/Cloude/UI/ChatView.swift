//
//  ChatView.swift
//  Cloude
//
//  Main chat interface
//

import SwiftUI

struct ChatMessage: Identifiable {
    let id = UUID()
    let isUser: Bool
    let text: String
    let timestamp: Date
}

struct ChatView: View {
    @ObservedObject var connection: ConnectionManager

    @State private var messages: [ChatMessage] = []
    @State private var inputText = ""
    @State private var currentOutput = ""
    @State private var scrollProxy: ScrollViewProxy?

    var body: some View {
        VStack(spacing: 0) {
            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(messages) { message in
                            MessageBubble(message: message)
                                .id(message.id)
                        }

                        // Current streaming output
                        if !currentOutput.isEmpty {
                            StreamingOutput(text: currentOutput)
                                .id("streaming")
                        }
                    }
                    .padding()
                }
                .onAppear {
                    scrollProxy = proxy
                }
                .onChange(of: messages.count) { _, _ in
                    scrollToBottom()
                }
                .onChange(of: currentOutput) { _, _ in
                    scrollToBottom()
                }
            }

            Divider()

            // Input area
            HStack(spacing: 12) {
                TextField("Message Claude...", text: $inputText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...5)
                    .onSubmit {
                        sendMessage()
                    }

                if connection.agentState == .running {
                    Button(action: {
                        connection.abort()
                    }) {
                        Image(systemName: "stop.circle.fill")
                            .font(.title2)
                            .foregroundColor(.orange)
                    }
                } else {
                    Button(action: sendMessage) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                            .foregroundColor(inputText.isEmpty ? .gray : .blue)
                    }
                    .disabled(inputText.isEmpty)
                }
            }
            .padding()
            .background(Color(.systemBackground))
        }
        .onAppear {
            connection.onOutput = { text in
                currentOutput += text
            }
        }
        .onChange(of: connection.agentState) { _, newState in
            if newState == .idle && !currentOutput.isEmpty {
                // Claude finished - save output as message
                messages.append(ChatMessage(
                    isUser: false,
                    text: currentOutput.trimmingCharacters(in: .whitespacesAndNewlines),
                    timestamp: Date()
                ))
                currentOutput = ""
            }
        }
    }

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        messages.append(ChatMessage(
            isUser: true,
            text: text,
            timestamp: Date()
        ))

        connection.sendChat(text)
        inputText = ""
    }

    private func scrollToBottom() {
        withAnimation(.easeOut(duration: 0.2)) {
            if !currentOutput.isEmpty {
                scrollProxy?.scrollTo("streaming", anchor: .bottom)
            } else if let last = messages.last {
                scrollProxy?.scrollTo(last.id, anchor: .bottom)
            }
        }
    }
}

struct MessageBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.isUser { Spacer(minLength: 50) }

            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 4) {
                Text(message.text)
                    .font(.body)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(message.isUser ? Color.blue : Color(.secondarySystemBackground))
                    .foregroundColor(message.isUser ? .white : .primary)
                    .cornerRadius(16)

                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            if !message.isUser { Spacer(minLength: 50) }
        }
    }
}

struct StreamingOutput: View {
    let text: String

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    ProgressView()
                        .scaleEffect(0.6)
                    Text("Claude is typing...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Text(text)
                    .font(.system(.body, design: .monospaced))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(16)
            }

            Spacer(minLength: 50)
        }
    }
}

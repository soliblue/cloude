//
//  ChatView+MessageBubble.swift
//  Cloude
//

import SwiftUI
import UIKit

struct MessageBubble: View {
    let message: ChatMessage
    @State private var showCopiedToast = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !message.isUser && !message.toolCalls.isEmpty {
                ToolCallsSection(toolCalls: message.toolCalls)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 4)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .top, spacing: 8) {
                    if message.isQueued {
                        Image(systemName: "clock")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    if message.wasInterrupted {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        if let imageBase64 = message.imageBase64,
                           let imageData = Data(base64Encoded: imageBase64),
                           let uiImage = UIImage(data: imageData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 36, height: 36)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }

                        if !message.text.isEmpty {
                            Group {
                                if message.isUser {
                                    Text(message.text)
                                } else {
                                    StreamingMarkdownView(text: message.text)
                                }
                            }
                            .font(.body)
                        }
                    }
                    .opacity(message.isQueued ? 0.6 : 1.0)
                }

                if !message.isUser, let durationMs = message.durationMs, let costUsd = message.costUsd {
                    HStack(spacing: 8) {
                        Text(message.timestamp, style: .time)
                            .font(.caption2)
                        RunStatsView(durationMs: durationMs, costUsd: costUsd)
                    }
                    .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, message.toolCalls.isEmpty ? 12 : 4)
            .padding(.bottom, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(message.isUser ? Color(.systemGray6) : Color(.systemBackground))
            .contextMenu {
                Button {
                    UIPasteboard.general.string = message.text
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation { showCopiedToast = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        withAnimation { showCopiedToast = false }
                    }
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }
            }
            .overlay(alignment: .top) {
                if showCopiedToast {
                    CopiedToast()
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
        }
    }
}

struct CopiedToast: View {
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.circle.fill")
            Text("Copied")
        }
        .font(.subheadline.weight(.medium))
        .foregroundColor(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color(.darkGray))
        .cornerRadius(20)
        .shadow(radius: 4)
        .padding(.top, 8)
    }
}

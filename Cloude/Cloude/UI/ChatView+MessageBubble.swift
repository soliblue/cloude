//
//  ChatView+MessageBubble.swift
//  Cloude
//

import SwiftUI
import UIKit

struct MessageBubble: View {
    let message: ChatMessage
    @State private var showTimestamp = false
    @State private var showCopiedToast = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !message.isUser && !message.toolCalls.isEmpty {
                ToolCallsSection(toolCalls: message.toolCalls)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
            }

            HStack(alignment: .top, spacing: 10) {
                if showTimestamp {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(message.timestamp, style: .time)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        if !message.isUser, let durationMs = message.durationMs, let costUsd = message.costUsd {
                            RunStatsView(durationMs: durationMs, costUsd: costUsd)
                        }
                    }
                    .transition(.move(edge: .leading).combined(with: .opacity))
                }

                Group {
                    if message.isUser {
                        Text(message.text)
                    } else {
                        RichTextView(text: message.text)
                    }
                }
                .font(.body)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(message.isUser ? Color(.systemGray6) : Color(.systemBackground))
            .gesture(
                DragGesture(minimumDistance: 20)
                    .onEnded { value in
                        let isSwipeRight = value.translation.width > 20
                        let isSwipeLeft = value.translation.width < -20
                        if isSwipeRight && !showTimestamp {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showTimestamp = true
                            }
                        } else if isSwipeLeft && showTimestamp {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showTimestamp = false
                            }
                        }
                    }
            )
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

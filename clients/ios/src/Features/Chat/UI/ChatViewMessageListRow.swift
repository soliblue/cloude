import SwiftUI
import UIKit

struct ChatViewMessageListRow: View {
    let session: Session
    let message: ChatMessage
    @Environment(\.filePreviewPresenter) private var presenter
    @State private var isSelectTextPresented = false
    @State private var isInfoPresented = false

    var body: some View {
        VStack(alignment: .leading, spacing: ThemeTokens.Spacing.xs) {
            if !message.imagesData.isEmpty {
                ChatViewMessageListRowAttachmentList(images: message.imagesData)
            }
            content
            if message.state == .failed && message.role == .assistant {
                Text("Failed")
                    .appFont(size: ThemeTokens.Text.s)
                    .foregroundColor(ThemeColor.danger)
            }
        }
        .contextMenu {
            if !message.text.isEmpty {
                Button {
                    UIPasteboard.general.string = message.text
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }
                Button {
                    isSelectTextPresented = true
                } label: {
                    Label("Select Text", systemImage: "text.cursor")
                }
            }
            Button {
                isInfoPresented = true
            } label: {
                Label("Info", systemImage: "info.circle")
            }
        }
        .sheet(isPresented: $isSelectTextPresented) {
            ChatViewMessageListRowSelectTextSheet(text: message.text)
        }
        .sheet(isPresented: $isInfoPresented) {
            ChatViewMessageListRowInfoSheet(message: message)
        }
        .environment(
            \.openURL,
            OpenURLAction { url in
                if let path = CloudeFileURL.path(from: url) {
                    presenter.open(session: session, path: path)
                    return .handled
                }
                return .systemAction
            })
    }

    @ViewBuilder private var content: some View {
        if message.state == .streaming {
            streaming
        } else {
            VStack(alignment: .leading, spacing: ThemeTokens.Spacing.s) {
                if message.hasThinking {
                    ChatViewMessageListRowThinking(
                        text: message.thinking, durationMs: message.thinkingMs,
                        redacted: message.thinkingRedacted)
                }
                if !message.text.isEmpty {
                    if message.role == .assistant {
                        ChatViewMessageListRowMarkdown(text: message.text).equatable()
                    } else {
                        Text(message.text)
                            .appFont(size: ThemeTokens.Text.m)
                    }
                }
            }
        }
    }

    @ViewBuilder private var streaming: some View {
        let snapshot = ChatLiveStream.snapshot(for: message.sessionId)
        if snapshot.isCompacting && snapshot.text.isEmpty {
            ChatViewMessageListRowCompactingPill()
        } else if snapshot.isThinking && snapshot.text.isEmpty {
            ChatViewMessageListRowThinking(text: "", durationMs: 0, isLive: true)
        } else if snapshot.text.isEmpty && !message.hasToolCalls {
            ProgressView().controlSize(.small)
        } else if !snapshot.text.isEmpty {
            VStack(alignment: .leading, spacing: ThemeTokens.Spacing.s) {
                if !snapshot.thinking.isEmpty || snapshot.thinkingMs > 0 {
                    ChatViewMessageListRowThinking(
                        text: snapshot.thinking, durationMs: snapshot.thinkingMs)
                }
                ChatViewMessageListRowStreamingMarkdown(snapshot: snapshot)
            }
        }
    }
}

import SwiftUI
import UIKit

struct ChatViewMessageListRow: View {
    let session: Session
    let message: ChatMessage
    @Environment(\.filePreviewPresenter) private var presenter
    @State private var isSelectTextPresented = false

    var body: some View {
        VStack(alignment: .leading, spacing: ThemeTokens.Spacing.xs) {
            if !message.imagesData.isEmpty {
                ChatViewMessageListRowAttachmentList(images: message.imagesData)
            }
            content
            if message.state == .failed {
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
        }
        .sheet(isPresented: $isSelectTextPresented) {
            ChatViewMessageListRowSelectTextSheet(text: message.text)
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
        } else if !message.text.isEmpty {
            if message.role == .assistant {
                ChatViewMessageListRowMarkdown(text: message.text).equatable()
            } else {
                Text(message.text)
                    .appFont(size: ThemeTokens.Text.m)
                    .textSelection(.enabled)
            }
        }
    }

    @ViewBuilder private var streaming: some View {
        let snapshot = ChatLiveStream.snapshot(for: message.sessionId)
        if snapshot.text.isEmpty && message.orderedToolCalls.isEmpty {
            ProgressView().controlSize(.small)
        } else if !snapshot.text.isEmpty {
            ChatViewMessageListRowStreamingMarkdown(text: snapshot.text)
        }
    }
}

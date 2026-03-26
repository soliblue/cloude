// MessageBubble+Footer.swift

import SwiftUI

struct MessageImageThumbnails: View {
    let message: ChatMessage

    var body: some View {
        if let thumbnails = message.imageThumbnails, thumbnails.count > 1 {
            HStack(spacing: 4) {
                ForEach(thumbnails.indices, id: \.self) { index in
                    if let imageData = Data(base64Encoded: thumbnails[index]),
                       let uiImage = UIImage(data: imageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 36, height: 36)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
            }
        } else if let imageBase64 = message.imageBase64,
                  let imageData = Data(base64Encoded: imageBase64),
                  let uiImage = UIImage(data: imageData) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .frame(width: 36, height: 36)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }
}

struct UserMessageFooter: View {
    let timestamp: Date
    let textCount: Int

    var body: some View {
        HStack(spacing: 8) {
            StatLabel(icon: "clock", text: DateFormatters.messageTimestamp(timestamp))
            StatLabel(icon: "textformat.size", text: "\(textCount)")
        }
        .foregroundColor(.secondary)
    }
}

struct AssistantMessageFooter: View {
    let message: ChatMessage
    var copyText: String
    @Binding var showCopiedToast: Bool
    let onRefresh: (() -> Void)?
    let isRefreshing: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                StatLabel(icon: "clock", text: DateFormatters.messageTimestamp(message.timestamp))
                if let durationMs = message.durationMs, let costUsd = message.costUsd {
                    RunStatsView(durationMs: durationMs, costUsd: costUsd, model: message.model)
                } else if let model = message.model {
                    StatLabel(icon: ModelIdentity(model).icon, text: ModelIdentity(model).displayName)
                }
                Spacer()
                Button {
                    CopyFeedback.perform(copyText, showToast: $showCopiedToast)
                } label: {
                    Image(systemName: showCopiedToast ? "checkmark" : "square.on.square")
                        .font(.system(size: DS.Text.footnote))
                        .foregroundColor(showCopiedToast ? .pastelGreen : .secondary)
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(.plain)
                if let onRefresh {
                    Button(action: onRefresh) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: DS.Text.footnote))
                            .foregroundColor(.secondary)
                            .symbolEffect(.rotate, options: .repeating, isActive: isRefreshing)
                    }
                    .buttonStyle(.plain)
                    .disabled(isRefreshing)
                }
            }
            .foregroundColor(.secondary)
        }
    }
}

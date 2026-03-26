import SwiftUI
import CloudeShared

struct FileAttachmentStrip: View {
    let files: [AttachedFile]
    let onRemove: (UUID) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(files) { file in
                    FileAttachmentPill(file: file, onRemove: { onRemove(file.id) })
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }
}

struct FileAttachmentPill: View {
    let file: AttachedFile
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: fileIconName(for: file.name))
                .font(.system(size: DS.Text.m, weight: .semibold))
            Text(file.name)
                .font(.system(size: DS.Text.s, weight: .medium))
                .lineLimit(1)
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: DS.Text.m))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .foregroundStyle(.cyan)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.cyan.opacity(0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.cyan.opacity(0.25), lineWidth: 1)
                )
        )
    }
}

struct PendingAudioBanner: View {
    let onResend: () -> Void
    let onDiscard: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "waveform.circle.fill")
                .font(.system(size: DS.Icon.m))
                .foregroundColor(.orange)

            Text("Unsent voice note")
                .font(.system(size: DS.Text.m))
                .foregroundColor(.secondary)

            Spacer()

            Button(action: onDiscard) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: DS.Icon.l))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)

            Button(action: onResend) {
                Text("Resend")
                    .font(.system(size: DS.Text.m, weight: .medium))
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .controlSize(.small)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }
}

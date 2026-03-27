import SwiftUI
import CloudeShared

struct FileAttachmentStrip: View {
    let files: [AttachedFile]
    let onRemove: (UUID) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DS.Spacing.s) {
                ForEach(files) { file in
                    FileAttachmentPill(file: file, onRemove: { onRemove(file.id) })
                }
            }
            .padding(.horizontal, DS.Spacing.l)
            .padding(.vertical, DS.Spacing.s)
        }
    }
}

struct FileAttachmentPill: View {
    let file: AttachedFile
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: DS.Spacing.s) {
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
        .padding(.horizontal, DS.Spacing.m)
        .padding(.vertical, DS.Spacing.s)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.m)
                .fill(Color.cyan.opacity(DS.Opacity.s))
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.m)
                        .stroke(Color.cyan.opacity(DS.Opacity.m), lineWidth: DS.Stroke.m)
                )
        )
    }
}

struct PendingAudioBanner: View {
    let onResend: () -> Void
    let onDiscard: () -> Void

    var body: some View {
        HStack(spacing: DS.Spacing.m) {
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
        .padding(.horizontal, DS.Spacing.l)
        .padding(.vertical, DS.Spacing.s)
        .background(.ultraThinMaterial)
    }
}

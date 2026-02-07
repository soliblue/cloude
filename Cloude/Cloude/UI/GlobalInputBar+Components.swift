import SwiftUI
import CloudeShared

struct AttachedImage: Identifiable {
    let id = UUID()
    let data: Data
    let isScreenshot: Bool
}

struct ImageAttachmentStrip: View {
    let images: [AttachedImage]
    let onRemove: (UUID) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(images) { image in
                    ImageAttachmentPill(
                        imageData: image.data,
                        isScreenshot: image.isScreenshot,
                        onRemove: { onRemove(image.id) }
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }
}

struct ImageAttachmentPill: View {
    let imageData: Data
    let isScreenshot: Bool
    let onRemove: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            if let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )
            }

            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.white)
                    .background(Circle().fill(Color.black.opacity(0.5)).frame(width: 14, height: 14))
            }
            .offset(x: 4, y: -4)

            if isScreenshot {
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(3)
                    .background(Circle().fill(Color.black.opacity(0.5)))
                    .offset(x: -2, y: 32)
            }
        }
    }
}

struct PendingAudioBanner: View {
    let onResend: () -> Void
    let onDiscard: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 20))
                .foregroundColor(.orange)

            Text("Unsent voice note")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Spacer()

            Button(action: onDiscard) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 22))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)

            Button(action: onResend) {
                Text("Resend")
                    .font(.subheadline.weight(.medium))
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

struct SlashCommandSuggestions: View {
    let commands: [SlashCommand]
    let onSelect: (SlashCommand) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(commands, id: \.name) { command in
                    Button(action: { onSelect(command) }) {
                        SkillPill(command: command)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }
}

struct SkillPill: View {
    let command: SlashCommand

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: command.icon)
                .font(.system(size: 14, weight: .semibold))
            Text("/\(command.name)")
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
        }
        .foregroundStyle(command.isSkill ? skillGradient : builtInGradient)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(SkillPillBackground(isSkill: command.isSkill))
    }
}

struct FileSuggestionsList: View {
    let files: [String]
    let onSelect: (String) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(files, id: \.self) { file in
                    Button(action: { onSelect(file) }) {
                        FilePill(path: file)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }
}

struct FilePill: View {
    let path: String

    private var fileName: String {
        path.lastPathComponent
    }

    private var icon: String {
        fileIconName(for: fileName)
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
            Text(fileName)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .lineLimit(1)
        }
        .foregroundStyle(fileGradient)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.orange.opacity(0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(
                            LinearGradient(
                                colors: [Color.orange.opacity(0.3), Color.yellow.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
    }

    private var fileGradient: LinearGradient {
        LinearGradient(
            colors: [.orange, .yellow.opacity(0.8)],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

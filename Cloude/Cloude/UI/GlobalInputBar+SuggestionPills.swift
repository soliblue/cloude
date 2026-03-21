import SwiftUI
import CloudeShared

struct SlashCommandSuggestions: View {
    let commands: [SlashCommand]
    let onSelect: (SlashCommand) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(commands, id: \.name) { command in
                    Button(action: { onSelect(command) }) {
                        SkillPill(command: command)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
        }
    }
}

struct SkillPill: View {
    let command: SlashCommand

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: command.icon)
                .font(.system(size: 11, weight: .semibold))
            Text("/\(command.name)")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
        }
        .foregroundStyle(command.isSkill ? skillGradient : builtInGradient)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(SkillPillBackground(isSkill: command.isSkill))
    }
}

struct HistorySuggestions: View {
    let suggestions: [String]
    let onSelect: (String) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(suggestions, id: \.self) { text in
                    Button(action: { onSelect(text) }) {
                        Text(text)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
        }
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
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.orange.opacity(0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
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

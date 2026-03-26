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
        Pill {
            Image(systemName: command.icon)
                .font(.system(size: DS.Pill.iconSize, weight: .semibold))
            Text("/\(command.name)")
                .font(.system(size: DS.Pill.textSize, weight: .semibold, design: .monospaced))
        } background: {
            SkillPillBackground(isSkill: command.isSkill)
        }
        .foregroundStyle(command.isSkill ? skillGradient : builtInGradient)
    }
}

struct HistorySuggestions: View {
    let suggestions: [HistoryEntry]
    let onSelect: (String) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(suggestions, id: \.text) { entry in
                    Button(action: { onSelect(entry.text) }) {
                        Pill {
                            Image(systemName: entry.symbol ?? "text.cursor")
                                .font(.system(size: DS.Pill.iconSize, weight: .medium))
                            Text(entry.text)
                                .font(.system(size: DS.Pill.textSize, weight: .medium))
                        } background: {
                            Color.secondary.opacity(0.08)
                        }
                        .foregroundColor(.secondary)
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
        Pill {
            Image(systemName: icon)
                .font(.system(size: DS.Pill.iconSize, weight: .semibold))
            Text(fileName)
                .font(.system(size: DS.Pill.textSize, weight: .semibold, design: .monospaced))
                .lineLimit(1)
        } background: {
            RoundedRectangle(cornerRadius: DS.Pill.cornerRadius)
                .fill(Color.orange.opacity(0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Pill.cornerRadius)
                        .stroke(
                            LinearGradient(
                                colors: [Color.orange.opacity(0.3), Color.yellow.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        }
        .foregroundStyle(fileGradient)
    }

    private var fileGradient: LinearGradient {
        LinearGradient(
            colors: [.orange, .yellow.opacity(0.8)],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

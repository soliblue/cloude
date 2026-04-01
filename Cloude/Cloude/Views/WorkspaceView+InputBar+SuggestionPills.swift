import SwiftUI
import CloudeShared

struct SlashCommandSuggestions: View {
    let commands: [SlashCommand]
    let onSelect: (SlashCommand) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DS.Spacing.s) {
                ForEach(commands, id: \.name) { command in
                    Button(action: { onSelect(command) }) {
                        SkillPill(command: command)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, DS.Spacing.l)
            .padding(.vertical, DS.Spacing.s)
        }
    }
}

struct SkillPill: View {
    let command: SlashCommand

    var body: some View {
        Pill {
            Image(systemName: command.icon)
                .font(.system(size: DS.Text.s, weight: .semibold))
            Text("/\(command.name)")
                .font(.system(size: DS.Text.s, weight: .semibold, design: .monospaced))
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
            HStack(spacing: DS.Spacing.s) {
                ForEach(suggestions, id: \.text) { entry in
                    Button(action: { onSelect(entry.text) }) {
                        Pill {
                            Image(systemName: entry.symbol ?? "text.cursor")
                                .font(.system(size: DS.Text.s, weight: .medium))
                            Text(entry.text)
                                .font(.system(size: DS.Text.s, weight: .medium))
                                .lineLimit(1)
                        } background: {
                            Color.secondary.opacity(DS.Opacity.s)
                        }
                        .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, DS.Spacing.l)
            .padding(.vertical, DS.Spacing.s)
        }
    }
}

struct FileSuggestionsList: View {
    let files: [String]
    let onSelect: (String) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DS.Spacing.s) {
                ForEach(files, id: \.self) { file in
                    Button(action: { onSelect(file) }) {
                        FilePill(path: file)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, DS.Spacing.l)
            .padding(.vertical, DS.Spacing.s)
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
                .font(.system(size: DS.Text.s, weight: .semibold))
            Text(fileName)
                .font(.system(size: DS.Text.s, weight: .semibold, design: .monospaced))
                .lineLimit(1)
        } background: {
            RoundedRectangle(cornerRadius: DS.Radius.s)
                .fill(Color.orange.opacity(DS.Opacity.s))
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.s)
                        .stroke(
                            LinearGradient(
                                colors: [Color.orange.opacity(DS.Opacity.m), Color.yellow.opacity(DS.Opacity.m)],
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
            colors: [.orange, .yellow.opacity(DS.Opacity.l)],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

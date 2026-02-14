import SwiftUI
import CloudeShared

struct SlashCommandBubble: View {
    let command: String
    var args: String? = nil
    let icon: String
    var isSkill: Bool = true

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
            Text(command)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
            if let args = args {
                Text(args)
                    .font(.system(size: 12, design: .monospaced))
                    .opacity(0.7)
                    .lineLimit(1)
            }
        }
        .foregroundStyle(isSkill ? skillGradient : builtInGradient)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(SkillPillBackground(isSkill: isSkill))
    }
}

func parseSlashCommand(text: String, skills: [Skill]) -> (name: String, args: String?, icon: String, isBuiltIn: Bool)? {
    guard text.hasPrefix("/") || text.contains("<command-name>") else { return nil }

    let commandName: String
    var commandArgs: String?
    if text.contains("<command-name>") {
        if let start = text.range(of: "<command-name>"),
           let end = text.range(of: "</command-name>") {
            let nameWithSlash = String(text[start.upperBound..<end.lowerBound])
            commandName = nameWithSlash.hasPrefix("/") ? String(nameWithSlash.dropFirst()) : nameWithSlash
        } else {
            return nil
        }
        if let argsStart = text.range(of: "<command-args>"),
           let argsEnd = text.range(of: "</command-args>") {
            let args = String(text[argsStart.upperBound..<argsEnd.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !args.isEmpty { commandArgs = args }
        }
    } else {
        let stripped = text.dropFirst()
        let parts = stripped.split(separator: " ", maxSplits: 1)
        commandName = String(parts.first ?? Substring(stripped))
        if parts.count > 1 {
            let args = String(parts[1]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !args.isEmpty { commandArgs = args }
        }
    }

    switch commandName {
    case "clear": return (commandName, commandArgs, "trash", true)
    case "compact": return (commandName, commandArgs, "arrow.triangle.2.circlepath", true)
    case "context": return (commandName, commandArgs, "chart.pie", true)
    case "cost": return (commandName, commandArgs, "dollarsign.circle", true)
    default:
        let skillIcon = skills.first(where: { $0.name == commandName })?.icon ?? "command"
        return (commandName, commandArgs, skillIcon, false)
    }
}

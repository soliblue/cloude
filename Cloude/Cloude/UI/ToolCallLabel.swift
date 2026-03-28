// ToolCallLabel.swift

import SwiftUI
import CloudeShared

struct ToolCallLabel: View {
    let name: String
    let input: String?
    private let iconSize: CGFloat = DS.Text.s
    private let textSize: CGFloat = DS.Text.s

    var body: some View {
        HStack(spacing: DS.Spacing.xs) {
            Image(systemName: iconName)
                .font(.system(size: iconSize, weight: .semibold))
            Text(displayName)
                .font(.system(size: textSize, weight: .semibold, design: .monospaced))
            if let detail = displayDetail {
                Text(detail)
                    .font(.system(size: textSize, design: .monospaced))
                    .opacity(DS.Opacity.l)
            }
        }
        .foregroundColor(toolCallColor(for: name, input: input))
    }

    private var toolCallProxy: ToolCall {
        ToolCall(name: name, input: input)
    }

    var isScript: Bool { toolCallProxy.isScript }

    static func isIOSControl(_ name: String) -> Bool {
        name.hasPrefix("mcp__ios__")
    }

    static func isWhiteboardTool(_ name: String) -> Bool {
        name.hasPrefix("mcp__whiteboard__")
    }

    private static let iosDisplayNames: [String: String] = [
        "rename": "Rename", "symbol": "Symbol", "notify": "Notify",
        "clipboard": "Clipboard", "open": "Open", "haptic": "Haptic",
        "switch": "Switch", "delete": "Delete", "skip": "Skip", "screenshot": "Screenshot"
    ]

    private static let whiteboardDisplayNames: [String: String] = [
        "open": "Open", "add": "Add",
        "remove": "Remove", "update": "Update",
        "clear": "Clear", "snapshot": "Snapshot",
        "viewport": "Viewport", "export": "Export"
    ]

    static let iosIcons: [String: String] = [
        "rename": "character.cursor.ibeam", "symbol": "star.square", "notify": "bell.fill",
        "clipboard": "doc.on.clipboard", "open": "safari", "haptic": "iphone.radiowaves.left.and.right",
        "switch": "arrow.left.arrow.right", "delete": "trash", "skip": "forward.fill", "screenshot": "camera.viewfinder"
    ]

    var iosAction: String? {
        ToolCallLabel.isIOSControl(name) ? String(name.dropFirst("mcp__ios__".count)) : nil
    }

    private var displayName: String {
        if let action = iosAction { return ToolCallLabel.iosDisplayNames[action] ?? action.capitalized }
        if ToolCallLabel.isWhiteboardTool(name) {
            let action = String(name.dropFirst("mcp__whiteboard__".count))
            return ToolCallLabel.whiteboardDisplayNames[action] ?? action.capitalized
        }
        if WidgetRegistry.isWidget(name) { return WidgetRegistry.displayName(name) }
        if name == "TodoWrite" { return "Tasks" }
        if name == "TeamCreate" { return "Team" }
        if name == "TeamDelete" { return "Team End" }
        if name == "SendMessage" { return "Message" }
        if name == "Skill", let input = input, !input.isEmpty {
            let skillName = input.split(separator: ":", maxSplits: 1).first.map(String.init) ?? input
            return "/\(skillName)"
        }
        if name == "Agent" { return agentCodename }
        guard name == "Bash", let input = input, !input.isEmpty else { return name }
        if isScript { return "Script" }
        let parsed = BashCommandParser.parse(input)
        var cmd = parsed.command
        if cmd.isEmpty { return name }
        if cmd.contains("/") {
            cmd = cmd.lastPathComponent
        }
        if let sub = parsed.subcommand, ["git", "npm", "yarn", "pnpm", "bun", "cargo", "docker", "kubectl", "pip", "pip3", "swift", "claude"].contains(cmd) {
            let combined = "\(cmd) \(sub)"
            return midTruncate(combined, maxLength: 12)
        }
        return midTruncate(cmd, maxLength: 10)
    }

    private var displayDetail: String? {
        guard let input = input, !input.isEmpty else { return nil }

        if let action = iosAction {
            let json = input.data(using: .utf8).flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] } ?? [:]
            switch action {
            case "rename": return (json["name"] as? String).map { truncateText($0, maxLength: 12) }
            case "symbol": return json["symbol"] as? String
            case "notify": return (json["message"] as? String).map { truncateText($0, maxLength: 12) }
            case "clipboard": return (json["text"] as? String).map { truncateText($0, maxLength: 12) }
            case "open": return (json["url"] as? String).map { truncateText($0, maxLength: 12) }
            case "haptic": return json["style"] as? String
            default: return nil
            }
        }

        switch name {
        case "Read", "Write", "Edit":
            return truncateFilename(input.lastPathComponent, maxLength: 8)
        case "Bash":
            if isScript { return nil }
            return bashDisplayDetail(input)
        case "Glob", "Grep":
            let truncated = input.prefix(8)
            return truncated.count < input.count ? "\(truncated)..." : String(input)
        case "Skill":
            let parts = input.split(separator: ":", maxSplits: 1)
            if parts.count >= 2 {
                let args = String(parts[1]).trimmingCharacters(in: .whitespaces)
                let truncated = args.prefix(16)
                return truncated.count < args.count ? "\(truncated)..." : args
            }
            return nil
        case "Task":
            return input.split(separator: ":", maxSplits: 1).first.map(String.init)
        case "TodoWrite":
            if let data = input.data(using: .utf8),
               let items = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                let completed = items.filter { ($0["status"] as? String) == "completed" }.count
                return "\(completed)/\(items.count)"
            }
            return nil
        default:
            return nil
        }
    }

    static let agentIcons = [
        "diamond.fill", "pentagon.fill", "hexagon.fill", "seal.fill", "octagon.fill", "shield.fill"
    ]

    static let agentCodenames = [
        "Claudius", "Solai", "Layl", "Archie", "Zein",
        "Gaudi", "Zima", "Hundertwasser", "Bauder",
        "Alan", "Luna", "Turing", "Cantor", "Andy"
    ]

    var agentIconName: String {
        let hash = abs((input ?? "").hashValue)
        return ToolCallLabel.agentIcons[hash % ToolCallLabel.agentIcons.count]
    }

    private var agentCodename: String {
        ToolCallLabel.agentCodenames[Int.random(in: 0..<ToolCallLabel.agentCodenames.count)]
    }
}

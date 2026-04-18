import SwiftUI
import CloudeShared

struct ToolMetadata {
    let name: String
    let input: String?

    var isWidget: Bool { WidgetRegistry.isWidget(name) }
    var isWhiteboardTool: Bool { name.hasPrefix("mcp__ios__whiteboard_") }
    var isIOSControl: Bool { name.hasPrefix("mcp__ios__") && !isWidget && !isWhiteboardTool }
    var isInert: Bool { name == "ToolSearch" }

    var isScript: Bool {
        name == "Bash" && (input.map { BashCommandParser.isScript($0) } ?? false)
    }

    var chainedCommands: [ChainedCommand] {
        guard name == "Bash", let input else { return [] }
        return BashCommandParser.chainedCommandsWithOperators(for: input)
    }

    var displayName: String {
        if let action = iosAction { return action.capitalized }
        if isWhiteboardTool { return String(name.dropFirst("mcp__ios__whiteboard_".count)).capitalized }
        if isWidget { return WidgetRegistry.displayName(name) }
        switch name {
        case "TodoWrite": return "Tasks"
        case "TeamCreate": return "Team"
        case "TeamDelete": return "Team End"
        case "SendMessage": return "Message"
        case "Skill" where input?.isEmpty == false:
            return "/\(input!.split(separator: ":", maxSplits: 1).first.map(String.init) ?? input!)"
        case "Agent": return agentCodename
        case "Bash": return bashDisplayName
        default: return name
        }
    }

    var detail: String? {
        guard let input, !input.isEmpty else { return nil }
        if let action = iosAction { return iosDetail(action, json: input) }
        switch name {
        case "Read", "Write", "Edit": return input.lastPathComponent.truncatedFilename(limit: 8)
        case "Bash": return isScript ? nil : bashDetail(input)
        case "Glob", "Grep": return input.truncated(limit: 8)
        case "Skill":
            let parts = input.split(separator: ":", maxSplits: 1)
            return parts.count >= 2 ? String(parts[1]).trimmingCharacters(in: .whitespaces).truncated(limit: 16) : nil
        case "Task": return input.split(separator: ":", maxSplits: 1).first.map(String.init)
        case "TodoWrite": return todoDetail(input)
        default: return nil
        }
    }

    var icon: String {
        if let action = iosAction { return Self.iosIcons[action] ?? "iphone" }
        if isWhiteboardTool { return "rectangle.on.rectangle.angled" }
        if isWidget { return WidgetRegistry.iconName(name) }
        switch name {
        case "Bash": return isScript ? "scroll" : bashIcon(input ?? "")
        case "Read": return "doc.text"
        case "Write": return "doc.badge.plus"
        case "Edit": return "pencil.line"
        case "Glob": return "folder.magnifyingglass"
        case "Grep": return "magnifyingglass"
        case "Task": return "person.2"
        case "WebFetch": return "globe"
        case "WebSearch": return "magnifyingglass.circle"
        case "TodoWrite": return "checklist"
        case "AskUserQuestion": return "questionmark.bubble"
        case "NotebookEdit": return "text.book.closed"
        case "Skill": return "command"
        case "TeamCreate", "TeamDelete": return "person.3.fill"
        case "SendMessage": return "paperplane.fill"
        case "Agent": return agentIcon
        default: return "gear"
        }
    }

    var color: Color {
        if isIOSControl { return AppColor.mint }
        if isWidget { return .secondary }
        if name == "Bash" {
            if isScript { return AppColor.teal }
            if let input { return bashColor(input) }
            return AppColor.green
        }
        return AppColor.tool(name)
    }

    var sheetTitle: String {
        switch name {
        case "TodoWrite": return "Tasks"
        case "Agent": return "Agent"
        default:
            if isIOSControl { return "iOS" }
            if isWhiteboardTool { return "Whiteboard" }
            if isWidget { return "Widget" }
            return name
        }
    }

    private var iosAction: String? {
        isIOSControl ? String(name.dropFirst("mcp__ios__".count)) : nil
    }

    private var agentCodename: String {
        Self.agentCodenames[abs((input ?? "").hashValue) % Self.agentCodenames.count]
    }

    private var agentIcon: String {
        Self.agentIcons[abs((input ?? "").hashValue) % Self.agentIcons.count]
    }

    private func iosDetail(_ action: String, json raw: String) -> String? {
        let json = raw.data(using: .utf8).flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] } ?? [:]
        switch action {
        case "rename": return (json["name"] as? String)?.truncated(limit: 12)
        case "symbol": return json["symbol"] as? String
        case "notify": return (json["message"] as? String)?.truncated(limit: 12)
        case "clipboard": return (json["text"] as? String)?.truncated(limit: 12)
        case "open": return (json["url"] as? String)?.truncatedURL(limit: 12)
        case "haptic": return json["style"] as? String
        default: return nil
        }
    }

    private func todoDetail(_ input: String) -> String? {
        if let data = input.data(using: .utf8),
           let items = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            return "\(items.filter { ($0["status"] as? String) == "completed" }.count)/\(items.count)"
        }
        return nil
    }

    private static let iosIcons: [String: String] = [
        "rename": "character.cursor.ibeam", "symbol": "star.square", "notify": "bell.fill",
        "clipboard": "doc.on.clipboard", "open": "safari", "haptic": "iphone.radiowaves.left.and.right",
        "switch": "arrow.left.arrow.right", "delete": "trash", "skip": "forward.fill", "screenshot": "camera.viewfinder"
    ]

    private static let agentIcons = [
        "diamond.fill", "pentagon.fill", "hexagon.fill", "seal.fill", "octagon.fill", "shield.fill"
    ]

    private static let agentCodenames = [
        "Claudius", "Solai", "Layl", "Archie", "Zein",
        "Gaudi", "Zima", "Hundertwasser", "Bauder",
        "Alan", "Luna", "Turing", "Cantor", "Andy"
    ]
}

extension String {
    func truncated(limit: Int) -> String {
        count > limit ? String(prefix(limit - 1)) + "…" : self
    }

    func truncatedPath(limit: Int) -> String {
        guard count > limit else { return self }
        let components = split(separator: "/")
        guard components.count > 1, let last = components.last else {
            return "…" + suffix(limit - 1)
        }
        return last.count >= limit - 3 ? "…/\(last.suffix(limit - 3))" : "…/\(last)"
    }

    func truncatedURL(limit: Int) -> String {
        var clean = self
        if clean.hasPrefix("https://") { clean = String(clean.dropFirst(8)) }
        else if clean.hasPrefix("http://") { clean = String(clean.dropFirst(7)) }
        if clean.hasPrefix("www.") { clean = String(clean.dropFirst(4)) }
        return clean.truncated(limit: limit)
    }

    func truncatedFilename(limit: Int) -> String {
        guard count > limit else { return self }
        let ext = pathExtension
        let name = deletingPathExtension
        let available = limit - ext.count - (ext.isEmpty ? 0 : 4)
        guard available > 0 else { return self }
        return "\(name.prefix(available))….\(ext)"
    }
}

// ToolCallLabel+Colors.swift

import SwiftUI

func toolCallColor(for name: String, input: String? = nil) -> Color {
    if ToolCallLabel.isIOSControl(name) { return .mint }
    if name == "Bash", let cmd = input {
        if BashCommandParser.isScript(cmd) { return .teal }
        return bashCommandColor(cmd)
    }
    switch name {
    case "Read": return .blue
    case "Write", "Edit": return .orange
    case "Bash": return .green
    case "Glob": return .purple
    case "Grep": return .pink
    case "Task": return .cyan
    case "WebFetch", "WebSearch": return .indigo
    case "TodoWrite": return .mint
    case "Skill": return .purple
    case "NotebookEdit": return .purple
    case "AskUserQuestion": return .orange
    case "TeamCreate", "TeamDelete": return .cyan
    case "SendMessage": return .teal
    case "Agent": return .yellow
    default:
        if WidgetRegistry.isWidget(name) { return WidgetRegistry.color(name) }
        return .secondary
    }
}

let bashColorMap: [String: Color] = [
    "cloude": .accentColor,
    "claude": .purple,
    "git": .orange,
    "npm": .red,
    "yarn": .red,
    "pnpm": .red,
    "bun": .red,
    "node": .green,
    "swift": .orange,
    "xcodebuild": .orange,
    "fastlane": .orange,
    "docker": .blue,
    "kubectl": .blue,
    "make": .purple,
    "ls": .cyan,
    "cd": .cyan,
    "pwd": .cyan,
    "mkdir": .cyan,
    "rmdir": .cyan,
    "rm": .red,
    "kill": .red,
    "killall": .red,
    "cp": .teal,
    "mv": .teal,
    "cat": .blue,
    "head": .blue,
    "tail": .blue,
    "less": .blue,
    "more": .blue,
    "curl": .indigo,
    "wget": .indigo,
    "ssh": .indigo,
    "scp": .indigo,
    "rsync": .indigo,
    "grep": .pink,
    "rg": .pink,
    "ag": .pink,
    "find": .pink,
    "fd": .pink,
    "brew": .yellow,
    "tar": .brown,
    "zip": .brown,
    "unzip": .brown,
    "gzip": .brown,
    "vim": .purple,
    "nvim": .purple,
    "nano": .purple,
    "emacs": .purple,
    "code": .purple,
    "pytest": .green,
    "jest": .green,
    "mocha": .green,
    "vitest": .green,
    "eslint": .purple,
    "prettier": .purple,
    "rubocop": .purple,
    "pip": .yellow,
    "pip3": .yellow,
    "python": .yellow,
    "python3": .yellow
]

let cargoColor = Color(red: 0.87, green: 0.46, blue: 0.19)

func bashCommandColor(_ cmd: String) -> Color {
    let parsed = BashCommandParser.parse(cmd)
    if parsed.command == "cargo" {
        return cargoColor
    }
    return bashColorMap[parsed.command] ?? .green
}

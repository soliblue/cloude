import SwiftUI

struct InlineToolPill: View {
    let toolCall: ToolCall
    var children: [ToolCall] = []
    @Environment(\.openURL) private var openURL
    @State private var showDetail = false
    @State private var isExpanded = false
    @State private var shimmerPhase: CGFloat = -1

    private var isMemoryCommand: Bool {
        toolCall.name == "Bash" && (toolCall.input?.hasPrefix("cloude memory ") ?? false)
    }

    private var isScript: Bool {
        guard toolCall.name == "Bash", let input = toolCall.input else { return false }
        return BashCommandParser.isScript(input)
    }

    private var chainedCommands: [String] {
        guard toolCall.name == "Bash", let input = toolCall.input else { return [] }
        if isScript { return [] }
        let commands = BashCommandParser.splitChainedCommands(input)
        return commands.count > 1 ? commands : []
    }

    private var filePath: String? {
        guard let input = toolCall.input else { return nil }

        if ["Read", "Write", "Edit"].contains(toolCall.name) {
            return input
        }

        if toolCall.name == "Bash" && !isMemoryCommand {
            return extractFilePathFromBash(input)
        }

        return nil
    }

    private func extractFilePathFromBash(_ command: String) -> String? {
        let parsed = BashCommandParser.parse(command)

        if parsed.command == "git", let sub = parsed.subcommand {
            let fileSubcommands = ["add", "diff", "checkout", "restore", "show"]
            if fileSubcommands.contains(sub), parsed.allArgs.count == 1 {
                let arg = parsed.allArgs[0]
                if isValidPath(arg) { return arg }
            }
        }

        let singlePathCommands = ["ls", "cd", "mkdir", "touch", "open", "cat", "head", "tail"]
        if singlePathCommands.contains(parsed.command) {
            if let arg = parsed.firstArg, isValidPath(arg) { return arg }
        }

        let destCommands = ["cp", "mv"]
        if destCommands.contains(parsed.command), parsed.allArgs.count == 2 {
            let dest = parsed.allArgs[1]
            if isValidPath(dest) { return dest }
        }

        return nil
    }

    private func isValidPath(_ path: String) -> Bool {
        path.hasPrefix("/") && !path.contains("*") && !path.contains("?")
    }

    private var hasQuickAction: Bool {
        if !chainedCommands.isEmpty { return false }
        return isMemoryCommand || filePath != nil
    }

    private func performQuickAction() {
        if isMemoryCommand {
            if let url = URL(string: "cloude://memory") {
                openURL(url)
            }
        } else if let path = filePath,
                  let encodedPath = path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
                  let url = URL(string: "cloude://file\(encodedPath)") {
            openURL(url)
        }
    }

    private func truncatedSummary(_ text: String) -> String {
        guard text.count > 40 else { return text }
        return String(text.prefix(37)) + "..."
    }

    private var isTaskTool: Bool {
        toolCall.name == "Task"
    }

    private var visibleChildren: [ToolCall] {
        if children.count > 5 && isExecuting {
            return Array(children.suffix(3))
        }
        return children
    }

    private var hiddenChildCount: Int {
        if children.count > 5 && isExecuting {
            return children.count - 3
        }
        return 0
    }

    var body: some View {
        Group {
            if children.isEmpty {
                pillContent
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    pillContent

                    if isExpanded {
                        if hiddenChildCount > 0 {
                            Text("\(hiddenChildCount) earlier tools...")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                                .padding(.leading, 16)
                        }
                        ForEach(visibleChildren, id: \.toolId) { child in
                            InlineToolPill(toolCall: child)
                                .padding(.leading, 16)
                        }
                    }
                }
            }
        }
        .onChange(of: children.count) { _, count in
            if count > 0 && isExecuting {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded = true
                }
            }
        }
        .onChange(of: toolCall.state) { _, newState in
            if newState == .complete && isTaskTool {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded = false
                }
            }
        }
        .highPriorityGesture(
            TapGesture()
                .onEnded {
                    if hasQuickAction {
                        performQuickAction()
                    } else {
                        showDetail = true
                    }
                }
        )
        .onLongPressGesture {
            showDetail = true
        }
        .sheet(isPresented: $showDetail) {
            ToolDetailSheet(toolCall: toolCall)
        }
    }

    private var isExecuting: Bool {
        toolCall.state == .executing
    }

    private var pillContent: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                if !chainedCommands.isEmpty {
                    chainedPillContent
                } else {
                    ToolCallLabel(name: toolCall.name, input: toolCall.input, size: .small)
                        .lineLimit(1)
                }

                if !children.isEmpty {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.secondary)
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isExpanded.toggle()
                            }
                        }
                }
            }

            if let summary = toolCall.resultSummary, toolCall.state == .complete {
                HStack(spacing: 3) {
                    Text("↳")
                        .font(.system(size: 10))
                    Text(truncatedSummary(summary))
                        .font(.system(size: 10, design: .monospaced))
                        .lineLimit(1)
                }
                .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(toolCallColor(for: toolCall.name, input: toolCall.input).opacity(0.12))
        .overlay {
            if isExecuting {
                ShimmerOverlay(phase: shimmerPhase)
                    .transition(.opacity)
            }
        }
        .cornerRadius(14)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .onChange(of: toolCall.state) { _, newState in
            if newState == .complete {
                withAnimation(.easeOut(duration: 0.3)) {
                    shimmerPhase = -1
                }
            }
        }
        .onAppear {
            if isExecuting {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false)) {
                    shimmerPhase = 2
                }
            }
        }
    }

    private var chainedPillContent: some View {
        HStack(spacing: 6) {
            ForEach(Array(chainedCommands.prefix(3).enumerated()), id: \.offset) { index, cmd in
                if index > 0 {
                    Image(systemName: "link")
                        .font(.system(size: 8))
                        .foregroundColor(.secondary)
                }
                let parsed = BashCommandParser.parse(cmd)
                Text(parsed.command.isEmpty ? "cmd" : parsed.command)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundColor(toolCallColor(for: "Bash", input: cmd))
            }
            if chainedCommands.count > 3 {
                Text("+\(chainedCommands.count - 3)")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct ShimmerOverlay: View {
    let phase: CGFloat

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .white.opacity(0.25), location: 0.4),
                    .init(color: .white.opacity(0.25), location: 0.6),
                    .init(color: .clear, location: 1)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: width * 0.6)
            .offset(x: width * phase)
        }
        .allowsHitTesting(false)
    }
}

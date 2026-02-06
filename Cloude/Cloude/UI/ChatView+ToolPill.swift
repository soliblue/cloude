import SwiftUI

struct InlineToolPill: View {
    let toolCall: ToolCall
    var children: [ToolCall] = []
    @State private var showDetail = false
    @State private var shimmerPhase: CGFloat = -1

    private var chainedCommands: [String] {
        guard toolCall.name == "Bash", let input = toolCall.input else { return [] }
        if BashCommandParser.isScript(input) { return [] }
        let commands = BashCommandParser.splitChainedCommands(input)
        return commands.count > 1 ? commands : []
    }

    private func truncatedSummary(_ text: String) -> String {
        guard text.count > 40 else { return text }
        return String(text.prefix(37)) + "..."
    }

    var body: some View {
        pillContent
        .highPriorityGesture(
            TapGesture()
                .onEnded {
                    showDetail = true
                }
        )
        .onLongPressGesture {
            showDetail = true
        }
        .sheet(isPresented: $showDetail) {
            ToolDetailSheet(toolCall: toolCall, children: children)
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
                    Text("\(children.count)")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.secondary.opacity(0.15))
                        .clipShape(Capsule())
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

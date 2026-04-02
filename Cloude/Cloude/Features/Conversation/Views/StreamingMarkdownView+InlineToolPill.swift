import SwiftUI

extension Notification.Name {
    static let openWhiteboard = Notification.Name("openWhiteboard")
}

struct InlineToolPill: View {
    let toolCall: ToolCall
    var children: [ToolCall] = []
    var onTap: (() -> Void)?
    @State private var shimmerPhase: CGFloat = -1

    private var chainedCommands: [ChainedCommand] {
        guard toolCall.name == "Bash", let input = toolCall.input else { return [] }
        return BashCommandParser.chainedCommandsWithOperators(for: input)
    }

    private var isIOSControl: Bool { ToolCallLabel.isIOSControl(toolCall.name) }
    private var isWhiteboardTool: Bool { ToolCallLabel.isWhiteboardTool(toolCall.name) }

    private var isInertTool: Bool { toolCall.name == "ToolSearch" }

    var body: some View {
        if isIOSControl || isInertTool {
            pillContent
        } else if isWhiteboardTool {
            Button {
                NotificationCenter.default.post(name: .openWhiteboard, object: nil)
            } label: {
                pillContent
            }
            .buttonStyle(.plain)
        } else {
            Button {
                onTap?()
            } label: {
                pillContent
            }
            .buttonStyle(.plain)
        }
    }

    private var isExecuting: Bool {
        toolCall.state == .executing
    }

    private var pillContent: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            HStack(spacing: DS.Spacing.xs) {
                if !chainedCommands.isEmpty {
                    chainedPillContent
                } else {
                    ToolCallLabel(name: toolCall.name, input: toolCall.input)
                        .lineLimit(1)
                }

                if !children.isEmpty {
                    Text("\(children.count)")
                        .font(.system(size: DS.Text.s, weight: .bold, design: .rounded))
                        .foregroundColor(.secondary)
                }
            }

        }
        .padding(.horizontal, DS.Spacing.s)
        .padding(.vertical, DS.Spacing.xs)
        .fixedSize(horizontal: false, vertical: true)
        .overlay {
            if isExecuting {
                ShimmerOverlay(phase: shimmerPhase)
                    .transition(.opacity)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.s))
        .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: DS.Radius.s))
        .onChange(of: toolCall.state) { _, newState in
            if newState == .complete {
                withAnimation(.easeOut(duration: DS.Duration.m)) {
                    shimmerPhase = -1
                }
            }
        }
        .onAppear {
            if isExecuting {
                withAnimation(.easeInOut(duration: DS.Duration.l * 4).repeatForever(autoreverses: true)) {
                    shimmerPhase = 1.5
                }
            } else {
                shimmerPhase = -1
            }
        }
    }

    private var chainedPillContent: some View {
        HStack(spacing: DS.Spacing.s) {
            ForEach(Array(chainedCommands.prefix(3).enumerated()), id: \.offset) { index, chained in
                if index > 0 {
                    let prevOp = chainedCommands[index - 1].operatorAfter
                    Text(prevOp == .pipe ? "|" : "›")
                        .font(.system(size: DS.Text.s, weight: .light))
                        .foregroundColor(.secondary)
                }
                let parsed = BashCommandParser.parse(chained.command)
                Text(parsed.command.isEmpty ? "cmd" : parsed.command)
                    .font(.system(size: DS.Text.s, weight: .semibold, design: .monospaced))
                    .foregroundColor(toolCallColor(for: "Bash", input: chained.command))
                    .lineLimit(1)
            }
            if chainedCommands.count > 3 {
                Text("+\(chainedCommands.count - 3)")
                    .font(.system(size: DS.Text.s, weight: .semibold))
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
                    .init(color: .white.opacity(DS.Opacity.m), location: 0.4),
                    .init(color: .white.opacity(DS.Opacity.m), location: 0.6),
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

import SwiftUI

extension Notification.Name {
    static let openWhiteboard = Notification.Name("openWhiteboard")
}

struct InlineToolPill: View {
    let toolCall: ToolCall
    var children: [ToolCall] = []
    @State private var showDetail = false
    @State private var shimmerPhase: CGFloat = -1

    private var chainedCommands: [ChainedCommand] {
        guard toolCall.name == "Bash", let input = toolCall.input else { return [] }
        return BashCommandParser.chainedCommandsWithOperators(for: input)
    }

    private var isIOSControl: Bool { ToolCallLabel.isIOSControl(toolCall.name) }
    private var isWhiteboardTool: Bool { ToolCallLabel.isWhiteboardTool(toolCall.name) }

    var body: some View {
        if isIOSControl {
            pillContent
        } else if isWhiteboardTool {
            pillContent
                .highPriorityGesture(
                    TapGesture()
                        .onEnded {
                            NotificationCenter.default.post(name: .openWhiteboard, object: nil)
                        }
                )
        } else {
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
                    ToolCallLabel(name: toolCall.name, input: toolCall.input)
                        .lineLimit(1)
                }

                if !children.isEmpty {
                    Text("\(children.count)")
                        .font(.caption2.weight(.bold))
                        .fontDesign(.rounded)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 3)
                        .padding(.vertical, 1)
                        .background(Color.secondary.opacity(0.15))
                        .clipShape(Capsule())
                }
            }

        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .fixedSize(horizontal: false, vertical: true)
        .overlay {
            if isExecuting {
                ShimmerOverlay(phase: shimmerPhase)
                    .transition(.opacity)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 8))
        .onChange(of: toolCall.state) { _, newState in
            if newState == .complete {
                withAnimation(.easeOut(duration: 0.3)) {
                    shimmerPhase = -1
                }
            }
        }
        .onAppear {
            if isExecuting {
                withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                    shimmerPhase = 1.5
                }
            } else {
                shimmerPhase = -1
            }
        }
    }

    private var chainedPillContent: some View {
        HStack(spacing: 6) {
            ForEach(Array(chainedCommands.prefix(3).enumerated()), id: \.offset) { index, chained in
                if index > 0 {
                    let prevOp = chainedCommands[index - 1].operatorAfter
                    Text(prevOp == .pipe ? "|" : "›")
                        .font(.caption2.weight(.light))
                        .foregroundColor(.secondary)
                }
                let parsed = BashCommandParser.parse(chained.command)
                Text(parsed.command.isEmpty ? "cmd" : parsed.command)
                    .font(.caption2.weight(.semibold).monospaced())
                    .foregroundColor(toolCallColor(for: "Bash", input: chained.command))
                    .lineLimit(1)
            }
            if chainedCommands.count > 3 {
                Text("+\(chainedCommands.count - 3)")
                    .font(.caption2.weight(.semibold))
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

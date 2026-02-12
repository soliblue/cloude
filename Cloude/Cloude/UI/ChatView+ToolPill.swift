import SwiftUI

struct InlineToolPill: View {
    let toolCall: ToolCall
    var children: [ToolCall] = []
    @State private var showDetail = false
    @State private var shimmerPhase: CGFloat = -1

    private var chainedCommands: [ChainedCommand] {
        guard toolCall.name == "Bash", let input = toolCall.input else { return [] }
        return BashCommandParser.chainedCommandsWithOperators(for: input)
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
                    ToolCallLabel(name: toolCall.name, input: toolCall.input)
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

        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(.ultraThinMaterial)
        .overlay {
            if isExecuting {
                ShimmerOverlay(phase: shimmerPhase)
                    .transition(.opacity)
            }
        }
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
                withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: false)) {
                    shimmerPhase = 2
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
                        .font(.system(size: 11, weight: .light))
                        .foregroundColor(.secondary)
                }
                let parsed = BashCommandParser.parse(chained.command)
                Text(parsed.command.isEmpty ? "cmd" : parsed.command)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(toolCallColor(for: "Bash", input: chained.command))
            }
            if chainedCommands.count > 3 {
                Text("+\(chainedCommands.count - 3)")
                    .font(.system(size: 11, weight: .semibold))
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

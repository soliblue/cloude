import SwiftUI
import CloudeShared

extension Notification.Name {
    static let openWhiteboard = Notification.Name("openWhiteboard")
}

struct InlineToolPill: View {
    let toolCall: ToolCall
    var children: [ToolCall] = []
    var onTap: (() -> Void)?
    @State private var shimmerPhase: CGFloat = -1

    private var meta: ToolMetadata { ToolMetadata(name: toolCall.name, input: toolCall.input) }
    private var isExecuting: Bool { toolCall.state == .executing }

    var body: some View {
        if meta.isIOSControl || meta.isInert {
            pillContent
        } else if meta.isWhiteboardTool {
            Button { NotificationCenter.default.post(name: .openWhiteboard, object: nil) } label: { pillContent }
                .buttonStyle(.plain)
        } else {
            Button { onTap?() } label: { pillContent }
                .buttonStyle(.plain)
        }
    }

    private var pillContent: some View {
        HStack(spacing: DS.Spacing.xs) {
            if !meta.chainedCommands.isEmpty {
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
                withAnimation(.easeOut(duration: DS.Duration.m)) { shimmerPhase = -1 }
            }
        }
        .onAppear {
            if isExecuting {
                withAnimation(.easeInOut(duration: DS.Duration.l * 4).repeatForever(autoreverses: true)) { shimmerPhase = 1.5 }
            } else {
                shimmerPhase = -1
            }
        }
    }

    private var chainedPillContent: some View {
        let commands = meta.chainedCommands
        return HStack(spacing: DS.Spacing.s) {
            ForEach(Array(commands.prefix(3).enumerated()), id: \.offset) { index, chained in
                if index > 0 {
                    Text(commands[index - 1].operatorAfter == .pipe ? "|" : "›")
                        .font(.system(size: DS.Text.s, weight: .light))
                        .foregroundColor(.secondary)
                }
                let parsed = BashCommandParser.parse(chained.command)
                Text(parsed.command.isEmpty ? "cmd" : parsed.command)
                    .font(.system(size: DS.Text.s, weight: .semibold, design: .monospaced))
                    .foregroundColor(ToolMetadata(name: "Bash", input: chained.command).color)
                    .lineLimit(1)
            }
            if commands.count > 3 {
                Text("+\(commands.count - 3)")
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

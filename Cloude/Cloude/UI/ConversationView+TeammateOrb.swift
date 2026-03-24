import SwiftUI
import CloudeShared

struct TeammateOrbRow: View {
    let teammate: TeammateInfo
    let onTap: () -> Void
    @State private var showBubble = false
    @State private var collapseWork: DispatchWorkItem?
    @State private var trackedMessage: String?

    private var orbColor: Color { teammateColor(teammate.color) }

    var body: some View {
        HStack(spacing: 6) {
            if showBubble, let msg = teammate.lastMessage {
                speechBubble(msg)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.6, anchor: .trailing).combined(with: .opacity),
                        removal: .opacity
                    ))
            }

            VStack(spacing: 3) {
                orbCircle
                Text(teammate.name)
                    .font(.caption2.weight(.medium))
                    .fontDesign(.rounded)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .frame(width: 40)
                HStack(spacing: 3) {
                    Text(modelBadge(teammate.model))
                    Text("·")
                    statusDot
                }
                .font(.caption2)
                .foregroundColor(Color(.tertiaryLabel))
            }
        }
        .onTapGesture(perform: onTap)
        .onChange(of: teammate.lastMessage) { _, newMsg in
            guard let newMsg, newMsg != trackedMessage else { return }
            trackedMessage = newMsg
            collapseWork?.cancel()
            withAnimation(.spring(duration: 0.35)) { showBubble = true }
            let work = DispatchWorkItem {
                withAnimation(.easeOut(duration: 0.3)) { showBubble = false }
            }
            collapseWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: work)
        }
    }

    private var orbCircle: some View {
        ZStack {
            pulseRing
            Circle()
                .fill(orbColor.opacity(0.6))
                .frame(width: 30, height: 30)
            Text(String(teammate.name.prefix(1)).uppercased())
                .font(.footnote.weight(.bold))
                .fontDesign(.rounded)
                .foregroundColor(.white)
            if !showBubble && teammate.unreadCount > 0 {
                unreadBadge
            }
        }
        .frame(width: 36, height: 36)
        .opacity(teammate.status == .idle ? 0.5 : 1.0)
    }

    @State private var isPulsing = false

    @ViewBuilder
    private var pulseRing: some View {
        if teammate.status == .working {
            Circle()
                .stroke(orbColor.opacity(0.3), lineWidth: 1.5)
                .frame(width: 34, height: 34)
                .scaleEffect(isPulsing ? 1.4 : 1.0)
                .opacity(isPulsing ? 0 : 0.5)
                .animation(.easeOut(duration: 1.5).repeatForever(autoreverses: false), value: isPulsing)
                .onAppear { isPulsing = true }
                .onChange(of: teammate.status) { _, s in isPulsing = (s == .working) }
        }
    }

    private var unreadBadge: some View {
        Circle()
            .fill(orbColor)
            .frame(width: 8, height: 8)
            .offset(x: 12, y: -12)
    }

    private var statusDot: some View {
        let (text, color): (String, Color) = {
            switch teammate.status {
            case .spawning: return ("Spawn", .orange)
            case .working: return ("Work", .pastelGreen)
            case .idle: return ("Idle", .secondary)
            case .shutdown: return ("Off", .pastelRed)
            }
        }()
        return Text(text).foregroundColor(color)
    }

    private func speechBubble(_ text: String) -> some View {
        Text(text)
            .font(.footnote)
            .foregroundColor(.primary)
            .lineLimit(3)
            .multilineTextAlignment(.leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(.ultraThinMaterial)
            .background(orbColor.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 9))
            .overlay(
                RoundedRectangle(cornerRadius: 9)
                    .strokeBorder(orbColor.opacity(0.2), lineWidth: 0.5)
            )
            .frame(maxWidth: 200, alignment: .trailing)
    }
}

// MessageBubble+ActionMenu.swift

import SwiftUI

struct BubbleActionMenu: View {
    let message: ChatMessage
    let onCopy: () -> Void
    let onSelectText: () -> Void
    let onToggleCollapse: (() -> Void)?
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            menuButton(icon: "doc.on.doc", label: "Copy") {
                onCopy()
                onDismiss()
            }
            if !message.text.isEmpty {
                divider
                menuButton(icon: "text.cursor", label: "Select") {
                    onSelectText()
                    onDismiss()
                }
            }
            if !message.isUser && !message.text.isEmpty {
                divider
                menuButton(icon: message.isCollapsed ? "chevron.down" : "chevron.up", label: message.isCollapsed ? "Expand" : "Collapse") {
                    onToggleCollapse?()
                    onDismiss()
                }
            }
        }
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.15), radius: 8, y: 2)
    }

    private func menuButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                Text(label)
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundColor(.primary)
            .frame(width: 64, height: 52)
        }
        .buttonStyle(.plain)
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.1))
            .frame(width: 0.5, height: 32)
    }
}

struct ConditionalClip: ViewModifier {
    let isClipped: Bool
    func body(content: Content) -> some View {
        if isClipped {
            content.clipped()
        } else {
            content
        }
    }
}

struct TeamSummaryBadge: View {
    let summary: TeamSummary
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 4) {
                HStack(spacing: -4) {
                    ForEach(summary.members) { member in
                        Circle()
                            .fill(teammateColor(member.color).opacity(0.6))
                            .frame(width: 14, height: 14)
                            .overlay {
                                Text(String(member.name.prefix(1)).uppercased())
                                    .font(.system(size: 7, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                            }
                    }
                }
                Text(summary.teamName)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.secondary.opacity(0.1))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

struct CopyFeedback {
    static func perform(_ text: String, showToast: Binding<Bool>) {
        ClipboardHelper.copy(text)
        withAnimation { showToast.wrappedValue = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation { showToast.wrappedValue = false }
        }
    }
}

struct BubbleLongPressOverlay: View {
    let message: ChatMessage
    var copyText: String
    let menuPressY: CGFloat
    @Binding var showCopiedToast: Bool
    let onSelectText: () -> Void
    let onToggleCollapse: (() -> Void)?
    let onDismiss: () -> Void

    var body: some View {
        GeometryReader { geo in
            let menuY = min(max(menuPressY - 60, 0), geo.size.height - 60)
            let origin = geo.frame(in: .global).origin
            Color.black.opacity(0.01)
                .frame(width: 10000, height: 10000)
                .position(x: 5000 - origin.x, y: 5000 - origin.y)
                .onTapGesture { onDismiss() }

            BubbleActionMenu(
                message: message,
                onCopy: {
                    CopyFeedback.perform(copyText, showToast: $showCopiedToast)
                },
                onSelectText: onSelectText,
                onToggleCollapse: onToggleCollapse,
                onDismiss: onDismiss
            )
            .transition(.opacity.combined(with: .scale(scale: 0.8)))
            .frame(maxWidth: .infinity)
            .offset(y: menuY)
        }
    }
}

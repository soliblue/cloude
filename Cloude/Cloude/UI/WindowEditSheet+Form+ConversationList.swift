import SwiftUI
import CloudeShared

struct SwipeToDeleteRow<Content: View>: View {
    let onTap: () -> Void
    let onDelete: () -> Void
    @ViewBuilder let content: () -> Content

    @State private var offset: CGFloat = 0
    @State private var showDelete = false
    @State private var isSwiping = false
    private let threshold: CGFloat = -70

    var body: some View {
        ZStack(alignment: .trailing) {
            if showDelete {
                Button(action: {
                    withAnimation(.easeOut(duration: 0.2)) {
                        offset = -400
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        onDelete()
                    }
                }) {
                    Image(systemName: "trash")
                        .font(.system(size: DS.Icon.s, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 70)
                        .frame(maxHeight: .infinity)
                        .background(Color.red)
                }
                .buttonStyle(.plain)
            }

            content()
                .background(Color.themeSecondary)
                .offset(x: offset)
                .onTapGesture {
                    if offset < 0 {
                        withAnimation(.easeOut(duration: 0.2)) { offset = 0 }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { showDelete = false }
                    } else {
                        onTap()
                    }
                }
                .highPriorityGesture(
                    DragGesture(minimumDistance: 30)
                        .onChanged { value in
                            let horizontal = abs(value.translation.width)
                            let vertical = abs(value.translation.height)
                            if !isSwiping && vertical > horizontal { return }
                            if value.translation.width < 0 {
                                offset = value.translation.width
                                showDelete = true
                                isSwiping = true
                            }
                        }
                        .onEnded { value in
                            if !isSwiping { return }
                            isSwiping = false
                            if value.translation.width < threshold {
                                withAnimation(.easeOut(duration: 0.2)) { offset = threshold }
                            } else {
                                withAnimation(.easeOut(duration: 0.2)) { offset = 0 }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { showDelete = false }
                            }
                        }
                )
        }
        .clipped()
    }
}

extension WindowEditForm {
    @ViewBuilder
    func conversationListSection() -> some View {
        if !allConversations.isEmpty {
            let visible = Array(allConversations.prefix(visibleCount))
            LazyVStack(spacing: 0) {
                ForEach(visible) { conv in
                    conversationRow(conv, isLast: conv.id == visible.last?.id)
                }

                if allConversations.count > visibleCount {
                    Button {
                        visibleCount += 20
                    } label: {
                        Text("\(allConversations.count - visibleCount) more")
                            .font(.caption)
                            .foregroundColor(.accentColor)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                }
            }
            .background(Color.themeSecondary)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    @ViewBuilder
    func conversationRow(_ conv: Conversation, isLast: Bool) -> some View {
        SwipeToDeleteRow(onTap: { onSelectConversation(conv) }, onDelete: {
            conversationStore.deleteConversation(conv)
        }) {
            HStack(spacing: 10) {
                Image.safeSymbol(conv.symbol)
                    .font(.system(size: 17))
                    .foregroundColor(.secondary)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(conv.name)
                        .font(.subheadline)
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        if let dir = conv.workingDirectory, !dir.isEmpty {
                            Text(dir.lastPathComponent)
                                .foregroundColor(.accentColor)
                        }
                        Text("\(conv.messages.count) msgs")
                            .foregroundColor(.secondary)
                    }
                    .font(.caption2)
                }
                Spacer()
                if let envId = conv.environmentId,
                   let env = environmentStore.environments.first(where: { $0.id == envId }) {
                    Image.safeSymbol(env.symbol)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                Text(relativeTime(conv.lastMessageAt))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }

        if !isLast {
            Divider()
                .padding(.leading, 46)
        }
    }

    func relativeTime(_ date: Date) -> String {
        let seconds = Int(-date.timeIntervalSinceNow)
        if seconds < 60 { return "now" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes)m ago" }
        let hours = minutes / 60
        if hours < 24 { return "\(hours)h ago" }
        let days = hours / 24
        return "\(days)d ago"
    }
}

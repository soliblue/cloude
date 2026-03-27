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
                    withAnimation(.easeOut(duration: DS.Duration.normal)) {
                        offset = -400
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        onDelete()
                    }
                }) {
                    Image(systemName: "trash")
                        .font(.system(size: DS.Icon.s, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: DS.Size.xl)
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
                        withAnimation(.easeOut(duration: DS.Duration.normal)) { offset = 0 }
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
                                withAnimation(.easeOut(duration: DS.Duration.normal)) { offset = threshold }
                            } else {
                                withAnimation(.easeOut(duration: DS.Duration.normal)) { offset = 0 }
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
                            .font(.system(size: DS.Text.s))
                            .foregroundColor(.accentColor)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, DS.Spacing.m)
                    }
                }
            }
            .background(Color.themeSecondary)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.m))
        }
    }

    @ViewBuilder
    func conversationRow(_ conv: Conversation, isLast: Bool) -> some View {
        SwipeToDeleteRow(onTap: { onSelectConversation(conv) }, onDelete: {
            conversationStore.deleteConversation(conv)
        }) {
            HStack(spacing: DS.Spacing.m) {
                Image.safeSymbol(conv.symbol)
                    .font(.system(size: DS.Text.m))
                    .foregroundColor(.secondary)
                    .frame(width: DS.Spacing.xl)
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Text(conv.name)
                        .font(.system(size: DS.Text.m))
                        .lineLimit(1)
                    HStack(spacing: DS.Spacing.s) {
                        if let dir = conv.workingDirectory, !dir.isEmpty {
                            Text(dir.lastPathComponent)
                                .foregroundColor(.accentColor)
                        }
                        Text("\(conv.messages.count) msgs")
                            .foregroundColor(.secondary)
                    }
                    .font(.system(size: DS.Text.s))
                }
                Spacer()
                if let envId = conv.environmentId,
                   let env = environmentStore.environments.first(where: { $0.id == envId }) {
                    Image.safeSymbol(env.symbol)
                        .font(.system(size: DS.Text.m))
                        .foregroundColor(.secondary)
                }
                Text(relativeTime(conv.lastMessageAt))
                    .font(.system(size: DS.Text.s))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, DS.Spacing.m)
            .padding(.vertical, DS.Spacing.m)
        }

        if !isLast {
            Divider()
                .padding(.leading, DS.Spacing.xxl)
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

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
                    withAnimation(.easeOut(duration: DS.Duration.s)) {
                        offset = -400
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + DS.Duration.s) {
                        onDelete()
                    }
                }) {
                    Image(systemName: "trash")
                        .font(.system(size: DS.Icon.s, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: DS.Size.l)
                        .frame(maxHeight: .infinity)
                        .background(Color.red)
                }
                .buttonStyle(.plain)
            }

            content()
                .offset(x: offset)
                .onTapGesture {
                    if offset < 0 {
                        withAnimation(.easeOut(duration: DS.Duration.s)) { offset = 0 }
                        DispatchQueue.main.asyncAfter(deadline: .now() + DS.Duration.s) { showDelete = false }
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
                                withAnimation(.easeOut(duration: DS.Duration.s)) { offset = threshold }
                            } else {
                                withAnimation(.easeOut(duration: DS.Duration.s)) { offset = 0 }
                                DispatchQueue.main.asyncAfter(deadline: .now() + DS.Duration.s) { showDelete = false }
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
            ConversationRowContent(
                symbol: conv.symbol,
                name: conv.name,
                messageCount: conv.messages.count,
                lastMessageAt: conv.lastMessageAt,
                envSymbol: conv.environmentId.flatMap { envId in
                    environmentStore.environments.first { $0.id == envId }?.symbol
                }
            )
            .padding(.horizontal, DS.Spacing.m)
            .padding(.vertical, DS.Spacing.m)
        }

        if !isLast {
            Divider()
                .padding(.leading, DS.Spacing.l)
        }
    }
}

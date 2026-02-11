import SwiftUI

struct ReadingProgressView: View {
    let progress: CGFloat
    let dotCount: Int = 5

    private var activeDot: Int {
        max(0, min(dotCount - 1, Int(progress * CGFloat(dotCount))))
    }

    var body: some View {
        VStack(spacing: 6) {
            ForEach(0..<dotCount, id: \.self) { index in
                Circle()
                    .fill(index <= activeDot ? Color.primary.opacity(0.5) : Color.primary.opacity(0.12))
                    .frame(width: 4, height: 4)
                    .animation(.easeOut(duration: 0.15), value: activeDot)
            }
        }
    }
}

struct MessageProgressTracker: ViewModifier {
    let isAssistantMessage: Bool
    let isCollapsed: Bool
    let viewportHeight: CGFloat

    @State private var progress: CGFloat = 0
    @State private var showIndicator = false

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .trailing) {
                if showIndicator && isAssistantMessage && !isCollapsed {
                    ReadingProgressView(progress: progress)
                        .padding(.trailing, 4)
                        .transition(.opacity)
                }
            }
            .background {
                GeometryReader { geo in
                    let scrollFrame = geo.frame(in: .named("chatScroll"))

                    Color.clear
                        .preference(
                            key: MessageVisibilityKey.self,
                            value: MessageVisibility(
                                messageTop: scrollFrame.minY,
                                messageHeight: geo.size.height
                            )
                        )
                }
            }
            .onPreferenceChange(MessageVisibilityKey.self) { visibility in
                let tall = visibility.messageHeight > viewportHeight * 1.3
                if tall != showIndicator {
                    withAnimation(.easeOut(duration: 0.2)) { showIndicator = tall }
                }

                if tall {
                    let visibleTop = max(0, -visibility.messageTop)
                    let scrollableHeight = visibility.messageHeight - viewportHeight
                    if scrollableHeight > 0 {
                        progress = min(1, max(0, visibleTop / scrollableHeight))
                    }
                }
            }
    }
}

private struct MessageVisibility: Equatable {
    let messageTop: CGFloat
    let messageHeight: CGFloat
}

private struct MessageVisibilityKey: PreferenceKey {
    static var defaultValue = MessageVisibility(messageTop: 0, messageHeight: 0)
    static func reduce(value: inout MessageVisibility, nextValue: () -> MessageVisibility) {
        value = nextValue()
    }
}

extension View {
    func readingProgress(isAssistant: Bool, isCollapsed: Bool, viewportHeight: CGFloat) -> some View {
        modifier(MessageProgressTracker(isAssistantMessage: isAssistant, isCollapsed: isCollapsed, viewportHeight: viewportHeight))
    }
}

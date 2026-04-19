import SwiftUI

struct Pill<Content: View, Background: View>: View {
    let content: Content
    let background: Background

    init(@ViewBuilder content: () -> Content, @ViewBuilder background: () -> Background) {
        self.content = content()
        self.background = background()
    }

    var body: some View {
        HStack(spacing: DS.Spacing.xs) {
            content
        }
        .padding(.horizontal, DS.Spacing.s)
        .padding(.vertical, DS.Spacing.xs)
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.s))
    }
}

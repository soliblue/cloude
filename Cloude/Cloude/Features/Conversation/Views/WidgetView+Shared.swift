import SwiftUI

extension Animation {
    static let quickTransition = Animation.easeInOut(duration: DS.Duration.s)
}

extension Notification.Name {
    static let editActiveWindow = Notification.Name("editActiveWindow")
}

struct WidgetContainer<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.m) { content() }
            .padding(DS.Spacing.l)
            .background(Color.themeSecondary.opacity(DS.Opacity.m))
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.l))
    }
}


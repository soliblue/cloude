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

struct WidgetHeader<Buttons: View>: View {
    let icon: String
    let title: String?
    let color: Color
    @ViewBuilder let buttons: () -> Buttons

    var body: some View {
        HStack(spacing: DS.Spacing.s) {
            Image(systemName: icon)
                .font(.system(size: DS.Text.s, weight: .semibold))
                .foregroundColor(color)
            if let title {
                Text(title)
                    .font(.system(size: DS.Text.m, weight: .medium))
                    .foregroundColor(.secondary)
            }
            Spacer()
            HStack(spacing: DS.Spacing.m) { buttons() }
        }
    }

    init(icon: String, title: String?, color: Color, @ViewBuilder buttons: @escaping () -> Buttons) {
        self.icon = icon
        self.title = title
        self.color = color
        self.buttons = buttons
    }
}

extension WidgetHeader where Buttons == EmptyView {
    init(icon: String, title: String?, color: Color) {
        self.icon = icon
        self.title = title
        self.color = color
        self.buttons = { EmptyView() }
    }
}

import SwiftUI

extension Animation {
    static let quickTransition = Animation.easeInOut(duration: DS.Duration.normal)
}

extension Notification.Name {
    static let widgetInputActive = Notification.Name("widgetInputActive")
    static let editActiveWindow = Notification.Name("editActiveWindow")
}

struct WidgetContainer<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.m) { content() }
            .padding(DS.Spacing.l)
            .background(Color.themeSecondary.opacity(DS.Opacity.strong))
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

struct WidgetButton: View {
    let icon: String
    let color: Color
    let enabled: Bool
    let action: () -> Void

    var body: some View {
        Button {
            withAnimation(.quickTransition) { action() }
        } label: {
            Image(systemName: icon)
                .font(.system(size: DS.Text.m, weight: .medium))
                .foregroundColor(enabled ? color : .secondary.opacity(DS.Opacity.strong))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}

struct WidgetResultBadge: View {
    let isCorrect: Bool
    let correctText: String
    let wrongText: String

    init(_ isCorrect: Bool, correct: String = "Correct!", wrong: String = "Wrong answer") {
        self.isCorrect = isCorrect
        self.correctText = correct
        self.wrongText = wrong
    }

    var body: some View {
        HStack(spacing: DS.Spacing.xs) {
            Image(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: DS.Text.s))
            Text(isCorrect ? correctText : wrongText)
                .font(.system(size: DS.Text.s, weight: .medium))
        }
        .foregroundColor(.secondary)
        .frame(maxWidth: .infinity)
    }
}

struct WidgetProgressBadge: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: DS.Spacing.xs) {
            Image(systemName: icon)
                .font(.system(size: DS.Text.s))
            Text(text)
                .font(.system(size: DS.Text.s, weight: .medium))
        }
        .foregroundColor(.secondary)
        .frame(maxWidth: .infinity)
    }
}

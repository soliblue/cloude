import SwiftUI

extension Animation {
    static let quickTransition = Animation.easeInOut(duration: 0.2)
}

extension Notification.Name {
    static let widgetInputActive = Notification.Name("widgetInputActive")
    static let editActiveWindow = Notification.Name("editActiveWindow")
}

struct WidgetContainer<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) { content() }
            .padding(14)
            .background(Color.themeSecondary.opacity(0.3))
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct WidgetHeader<Buttons: View>: View {
    let icon: String
    let title: String?
    let color: Color
    @ViewBuilder let buttons: () -> Buttons

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(color)
            if let title {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }
            Spacer()
            HStack(spacing: 12) { buttons() }
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
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(enabled ? color : .secondary.opacity(0.3))
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
        HStack(spacing: 4) {
            Image(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 10))
            Text(isCorrect ? correctText : wrongText)
                .font(.system(size: 11, weight: .medium))
        }
        .foregroundColor(.secondary)
        .frame(maxWidth: .infinity)
    }
}

struct WidgetProgressBadge: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10))
            Text(text)
                .font(.system(size: 11, weight: .medium))
        }
        .foregroundColor(.secondary)
        .frame(maxWidth: .infinity)
    }
}

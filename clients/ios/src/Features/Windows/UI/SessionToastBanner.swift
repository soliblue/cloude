import SwiftUI

struct SessionToastBanner: View {
    let toast: SessionToast
    let onTap: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: ThemeTokens.Spacing.m) {
                Image(systemName: toast.symbol)
                    .appFont(size: ThemeTokens.Text.l, weight: .medium)
                    .foregroundColor(.primary)
                    .frame(width: ThemeTokens.Icon.xl, height: ThemeTokens.Icon.xl)
                VStack(alignment: .leading, spacing: ThemeTokens.Spacing.xs) {
                    Text(toast.title)
                        .appFont(size: ThemeTokens.Text.m, weight: .semibold)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    Text(toast.snippet)
                        .appFont(size: ThemeTokens.Text.s)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, ThemeTokens.Spacing.l)
            .padding(.vertical, ThemeTokens.Spacing.m)
            .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: ThemeTokens.Radius.l))
            .contentShape(RoundedRectangle(cornerRadius: ThemeTokens.Radius.l))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, ThemeTokens.Spacing.m)
        .gesture(
            DragGesture(minimumDistance: 10)
                .onEnded { value in
                    if value.translation.height < -20 { onDismiss() }
                }
        )
    }
}

import SwiftUI

struct SessionEmptyViewPickerOption: Identifiable {
    let id: String
    let title: String
    let isSelected: Bool
    let action: () -> Void
}

struct SessionEmptyViewPickerRow: View {
    let icon: String
    let title: String
    let value: String
    let options: [SessionEmptyViewPickerOption]
    @State private var isPopoverPresented = false

    var body: some View {
        Button {
            isPopoverPresented = true
        } label: {
            HStack(spacing: ThemeTokens.Spacing.s) {
                Image(systemName: icon)
                    .appFont(size: ThemeTokens.Text.l)
                VStack(alignment: .leading, spacing: 0) {
                    Text(title)
                        .appFont(size: ThemeTokens.Text.s, weight: .medium)
                        .foregroundColor(.secondary)
                    Text(value)
                        .appFont(size: ThemeTokens.Text.m, weight: .medium)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "chevron.up.chevron.down")
                    .appFont(size: ThemeTokens.Text.s, weight: .medium)
                    .foregroundColor(.secondary)
            }
            .foregroundColor(.primary)
            .padding(.horizontal, ThemeTokens.Spacing.m)
            .padding(.vertical, ThemeTokens.Spacing.m)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .popover(isPresented: $isPopoverPresented, arrowEdge: .top) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(options) { option in
                    Button {
                        option.action()
                        isPopoverPresented = false
                    } label: {
                        HStack {
                            Text(option.title)
                                .appFont(size: ThemeTokens.Text.m, weight: .medium)
                            Spacer(minLength: 0)
                            if option.isSelected {
                                Image(systemName: "checkmark")
                                    .appFont(size: ThemeTokens.Text.s, weight: .semibold)
                            }
                        }
                        .foregroundColor(.primary)
                        .padding(.horizontal, ThemeTokens.Spacing.m)
                        .padding(.vertical, ThemeTokens.Spacing.s)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, ThemeTokens.Spacing.xs)
            .padding(.vertical, ThemeTokens.Spacing.xs)
            .frame(minWidth: 200)
            .presentationCompactAdaptation(.popover)
        }
    }
}

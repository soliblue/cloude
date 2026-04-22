import SwiftUI

struct SettingsViewAccentPicker: View {
    @AppStorage(StorageKey.appAccent) private var selectedAccent: AppAccent = .clay

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                ForEach(Array(AppAccent.allCases.enumerated()), id: \.element) { index, accent in
                    if index > 0 { Divider() }
                    HStack(spacing: ThemeTokens.Spacing.m) {
                        Circle()
                            .fill(accent.color)
                            .frame(width: ThemeTokens.Size.m, height: ThemeTokens.Size.m)
                        Text(accent.rawValue)
                            .appFont(
                                size: ThemeTokens.Text.m,
                                weight: selectedAccent == accent ? .semibold : .regular
                            )
                            .foregroundColor(selectedAccent == accent ? .primary : .secondary)
                        Spacer()
                        if selectedAccent == accent {
                            Image(systemName: "checkmark")
                                .appFont(size: ThemeTokens.Text.m, weight: .semibold)
                        }
                    }
                    .padding(.vertical, ThemeTokens.Spacing.m)
                    .contentShape(Rectangle())
                    .onTapGesture { selectedAccent = accent }
                }
            }
            .padding(.horizontal, ThemeTokens.Spacing.m)
        }
        .themedNavChrome()
    }
}

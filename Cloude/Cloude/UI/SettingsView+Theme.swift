import SwiftUI

struct ThemePickerView: View {
    @AppStorage("appTheme") private var appThemeRaw: String = AppTheme.majorelle.rawValue
    private var appTheme: AppTheme { AppTheme(rawValue: appThemeRaw) ?? .majorelle }
    @Environment(\.dismiss) private var dismiss

    private let columns = [
        GridItem(.flexible(), spacing: DS.Spacing.s),
        GridItem(.flexible(), spacing: DS.Spacing.s),
        GridItem(.flexible(), spacing: DS.Spacing.s)
    ]

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                LazyVGrid(columns: columns, spacing: DS.Spacing.m) {
                    ForEach(AppTheme.allCases, id: \.self) { theme in
                        ThemeCard(theme: theme, isSelected: appTheme == theme, currentTheme: appTheme)
                            .onTapGesture { appThemeRaw = theme.rawValue }
                    }
                }
                .padding(DS.Spacing.m)
            }
            .background(Color(hex: appTheme.palette.background))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color(hex: appTheme.palette.secondary), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: DS.Icon.s, weight: .medium))
                    }
                }
            }
        .preferredColorScheme(appTheme.colorScheme)
        }
    }
}

struct ThemeCard: View {
    let theme: AppTheme
    let isSelected: Bool
    let currentTheme: AppTheme

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: DS.Spacing.xs) {
                RoundedRectangle(cornerRadius: DS.Radius.s)
                    .fill(Color(hex: theme.palette.background))
                    .frame(height: 32)
                RoundedRectangle(cornerRadius: DS.Radius.s)
                    .fill(Color(hex: theme.palette.secondary))
                    .frame(height: 32)
            }
            .padding(DS.Spacing.s)

            Text(theme.rawValue)
                .font(.system(size: DS.Text.m, weight: isSelected ? .semibold : .regular))
                .foregroundColor(isSelected ? .primary : .secondary)
                .padding(.bottom, DS.Spacing.s)
        }
        .background(Color(hex: currentTheme.palette.secondary))
        .cornerRadius(DS.Radius.m)
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.m)
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
        )
    }
}

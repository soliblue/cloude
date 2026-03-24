import SwiftUI

struct ThemePickerView: View {
    @AppStorage("appTheme") private var appThemeRaw: String = AppTheme.majorelle.rawValue
    private var appTheme: AppTheme { AppTheme(rawValue: appThemeRaw) ?? .majorelle }
    @Environment(\.dismiss) private var dismiss

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(AppTheme.allCases, id: \.self) { theme in
                        ThemeCard(theme: theme, isSelected: appTheme == theme, currentTheme: appTheme)
                            .onTapGesture { appThemeRaw = theme.rawValue }
                    }
                }
                .padding(12)
            }
            .background(Color(hex: appTheme.palette.background))
            .navigationTitle("Theme")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color(hex: appTheme.palette.secondary), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
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
            HStack(spacing: 3) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color(hex: theme.palette.background))
                    .frame(height: 32)
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color(hex: theme.palette.secondary))
                    .frame(height: 32)
            }
            .padding(8)

            Text(theme.rawValue)
                .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                .foregroundColor(isSelected ? .primary : .secondary)
                .padding(.bottom, 8)
        }
        .background(Color(hex: currentTheme.palette.secondary))
        .cornerRadius(9)
        .overlay(
            RoundedRectangle(cornerRadius: 9)
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
        )
    }
}

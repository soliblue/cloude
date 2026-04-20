import SwiftUI

private struct ThemeKey: EnvironmentKey {
    static let defaultValue: Theme = .majorelle
}

private struct FontStepKey: EnvironmentKey {
    static let defaultValue: CGFloat = 0
}

extension EnvironmentValues {
    var theme: Theme {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }

    var fontStep: CGFloat {
        get { self[FontStepKey.self] }
        set { self[FontStepKey.self] = newValue }
    }
}

extension View {
    func appFont(size: CGFloat, weight: Font.Weight = .regular, design: Font.Design = .default) -> some View {
        modifier(AppFont(size: size, weight: weight, design: design))
    }

    func themedNavChrome() -> some View {
        modifier(ThemedNavChrome())
    }
}

private struct AppFont: ViewModifier {
    @Environment(\.fontStep) private var step
    let size: CGFloat
    let weight: Font.Weight
    let design: Font.Design

    func body(content: Content) -> some View {
        content.font(.system(size: size + step, weight: weight, design: design))
    }
}

private struct ThemedNavChrome: ViewModifier {
    @Environment(\.theme) private var theme

    func body(content: Content) -> some View {
        content
            .background(theme.palette.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(theme.palette.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
    }
}

import SwiftUI
import CloudeShared

struct SettingsRow<Content: View>: View {
    let icon: String
    let color: Color
    @ViewBuilder let content: Content

    var body: some View {
        HStack(spacing: DS.Spacing.m) {
            Image(systemName: icon)
                .font(.system(size: DS.Icon.m))
                .foregroundColor(color)
            content
        }
    }
}

import SwiftUI

struct EndpointsCarouselAdd: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .appFont(size: ThemeTokens.Icon.l, weight: .light)
                .foregroundColor(.secondary.opacity(ThemeTokens.Opacity.m))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .buttonStyle(.plain)
    }
}

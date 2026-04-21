import SwiftUI

struct ChatViewMessageListRowToolPillListRowShimmer: View {
    let phase: CGFloat
    let tint: Color

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: tint.opacity(ThemeTokens.Opacity.m), location: 0.4),
                    .init(color: tint.opacity(ThemeTokens.Opacity.m), location: 0.6),
                    .init(color: .clear, location: 1),
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: width * 0.6)
            .offset(x: width * phase)
        }
        .allowsHitTesting(false)
    }
}

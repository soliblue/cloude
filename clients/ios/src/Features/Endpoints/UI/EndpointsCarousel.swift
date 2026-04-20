import SwiftUI

struct EndpointsCarousel: View {
    @EnvironmentObject private var store: EndpointsStore
    @Environment(\.fontStep) private var fontStep
    @State private var selectedPage = 0

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $selectedPage) {
                ForEach(Array(store.endpoints.enumerated()), id: \.element.id) { index, _ in
                    EndpointsCarouselCard(endpoint: $store.endpoints[index])
                        .tag(index)
                }
                EndpointsCarouselAdd {
                    store.endpoints.append(Endpoint())
                    selectedPage = store.endpoints.count - 1
                }
                .tag(store.endpoints.count)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: ThemeTokens.Size.xxl)

            HStack(spacing: ThemeTokens.Spacing.s) {
                ForEach(0..<store.endpoints.count + 1, id: \.self) { index in
                    Circle()
                        .fill(index == selectedPage ? Color.accentColor : Color.secondary.opacity(ThemeTokens.Opacity.m))
                        .frame(width: ThemeTokens.Size.s, height: ThemeTokens.Size.s)
                }
            }
            .padding(.top, fontStep)
            .padding(.bottom, ThemeTokens.Spacing.s)
            .frame(maxWidth: .infinity)
        }
    }
}

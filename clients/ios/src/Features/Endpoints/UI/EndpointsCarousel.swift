import SwiftData
import SwiftUI

struct EndpointsCarousel: View {
    @Environment(\.fontStep) private var fontStep
    @Environment(\.modelContext) private var context
    @Query(sort: \Endpoint.createdAt) private var endpoints: [Endpoint]
    @State private var selectedPage = 0

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $selectedPage) {
                ForEach(Array(endpoints.enumerated()), id: \.element.id) { index, endpoint in
                    EndpointsCarouselCard(endpoint: endpoint, canDelete: endpoints.count > 1)
                        .tag(index)
                }
                EndpointsCarouselAdd {
                    EndpointActions.add(into: context)
                    selectedPage = endpoints.count
                }
                .tag(endpoints.count)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: ThemeTokens.Size.xxl)

            HStack(spacing: ThemeTokens.Spacing.s) {
                ForEach(0..<endpoints.count + 1, id: \.self) { index in
                    Circle()
                        .fill(
                            index == selectedPage
                                ? Color.accentColor : Color.secondary.opacity(ThemeTokens.Opacity.m)
                        )
                        .frame(width: ThemeTokens.Size.s, height: ThemeTokens.Size.s)
                }
            }
            .padding(.top, fontStep)
            .padding(.bottom, ThemeTokens.Spacing.s)
            .frame(maxWidth: .infinity)
        }
    }
}

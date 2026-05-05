import SwiftData
import SwiftUI

struct EndpointsListView: View {
    @Environment(\.theme) private var theme
    @Query(sort: \Endpoint.createdAt) private var endpoints: [Endpoint]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: ThemeTokens.Spacing.l) {
                ForEach(Array(endpoints.enumerated()), id: \.element.id) { index, endpoint in
                    NavigationLink {
                        EndpointView(existing: endpoint, canDelete: endpoints.count > 1)
                    } label: {
                        HStack(spacing: ThemeTokens.Spacing.m) {
                            WindowsSidebarRow(
                                symbol: endpoint.symbolName,
                                title: endpoint.displayName,
                                isFocused: false
                            )
                            Spacer()
                            Image(systemName: "pencil.circle.fill")
                                .appFont(size: ThemeTokens.Text.l)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    if index < endpoints.count - 1 {
                        Divider()
                    }
                }
            }
            .padding(.horizontal, ThemeTokens.Spacing.l)
            .padding(.vertical, ThemeTokens.Spacing.m)
        }
        .background(theme.palette.background)
        .navigationTitle("Endpoints")
        .navigationBarTitleDisplayMode(.inline)
        .themedNavChrome()
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    NotificationCenter.default.post(name: .openOnboarding, object: OnboardingStep.pair)
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
    }
}

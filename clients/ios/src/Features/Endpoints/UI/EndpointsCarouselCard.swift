import SwiftUI

struct EndpointsCarouselCard: View {
    @Binding var endpoint: Endpoint
    @State private var authKey: String

    init(endpoint: Binding<Endpoint>) {
        self._endpoint = endpoint
        _authKey = State(initialValue: SecureStorage.get(account: endpoint.wrappedValue.id.uuidString) ?? "")
    }

    var body: some View {
        VStack(spacing: ThemeTokens.Spacing.m) {
            EndpointsCarouselCardHeader(endpoint: $endpoint, authKey: authKey)
            EndpointsCarouselCardForm(endpoint: $endpoint, authKey: $authKey)
        }
        .padding(.bottom, ThemeTokens.Spacing.xs)
        .padding(.horizontal, ThemeTokens.Spacing.xs)
    }
}

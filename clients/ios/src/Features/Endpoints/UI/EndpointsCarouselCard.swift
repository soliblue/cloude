import SwiftData
import SwiftUI

struct EndpointsCarouselCard: View {
    @Bindable var endpoint: Endpoint
    let canDelete: Bool
    @State private var authKey: String

    init(endpoint: Endpoint, canDelete: Bool) {
        self.endpoint = endpoint
        self.canDelete = canDelete
        _authKey = State(initialValue: SecureStorage.get(account: endpoint.id.uuidString) ?? "")
    }

    var body: some View {
        VStack(spacing: ThemeTokens.Spacing.m) {
            EndpointsCarouselCardHeader(endpoint: endpoint, authKey: authKey, canDelete: canDelete)
            EndpointsCarouselCardForm(endpoint: endpoint, authKey: $authKey)
        }
        .padding(.bottom, ThemeTokens.Spacing.xs)
        .padding(.horizontal, ThemeTokens.Spacing.xs)
    }
}

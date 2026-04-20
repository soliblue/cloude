import SwiftUI

struct EndpointsCarouselCardForm: View {
    @Binding var endpoint: Endpoint
    @Binding var authKey: String
    @EnvironmentObject private var store: EndpointsStore
    @Environment(\.theme) private var theme
    @State private var isTokenVisible = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: ThemeTokens.Spacing.m) {
                Image(systemName: "server.rack")
                    .appFont(size: ThemeTokens.Icon.m)
                    .foregroundColor(ThemeColor.blue)
                TextField("Host", text: $endpoint.host)
                    .appFont(size: ThemeTokens.Text.m)
                    .textFieldStyle(.plain)
                    .textContentType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
            }
            .padding(.vertical, ThemeTokens.Spacing.m)

            Divider().padding(.leading, ThemeTokens.Spacing.l)

            HStack(spacing: ThemeTokens.Spacing.m) {
                Image(systemName: "number")
                    .appFont(size: ThemeTokens.Icon.m)
                    .foregroundColor(ThemeColor.blue)
                TextField("Port", value: $endpoint.port, format: .number.grouping(.never))
                    .appFont(size: ThemeTokens.Text.m, design: .monospaced)
                    .textFieldStyle(.plain)
                    .keyboardType(.numberPad)
            }
            .padding(.vertical, ThemeTokens.Spacing.m)

            Divider().padding(.leading, ThemeTokens.Spacing.l)

            HStack(spacing: ThemeTokens.Spacing.m) {
                Image(systemName: "key.fill")
                    .appFont(size: ThemeTokens.Icon.m)
                    .foregroundColor(ThemeColor.orange)

                Group {
                    if isTokenVisible {
                        TextField("Auth Token", text: $authKey)
                            .appFont(size: ThemeTokens.Text.m, design: .monospaced)
                            .textFieldStyle(.plain)
                    } else {
                        SecureField("Auth Token", text: $authKey)
                            .appFont(size: ThemeTokens.Text.m, design: .monospaced)
                            .textFieldStyle(.plain)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

                Button { isTokenVisible.toggle() } label: {
                    Image(systemName: isTokenVisible ? "eye.slash.fill" : "eye.fill")
                        .appFont(size: ThemeTokens.Text.m)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, ThemeTokens.Spacing.m)
        }
        .padding(.horizontal, ThemeTokens.Spacing.m)
        .background(theme.palette.surface)
        .clipShape(RoundedRectangle(cornerRadius: ThemeTokens.Radius.m))
        .onDisappear {
            if store.endpoints.contains(where: { $0.id == endpoint.id }) {
                SecureStorage.set(account: endpoint.id.uuidString, value: authKey)
            }
        }
    }
}

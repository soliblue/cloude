import SwiftUI

struct OnboardingViewManualSheet: View {
    let onPayload: (OnboardingPairingPayload) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme
    @State private var host = ""
    @State private var port = 8765
    @State private var token = ""
    @State private var name = ""

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: ThemeTokens.Spacing.l) {
                    field(label: "Host", icon: "server.rack", tint: ThemeColor.blue) {
                        TextField("192.168.1.20", text: $host)
                            .appFont(size: ThemeTokens.Text.m)
                            .textFieldStyle(.plain)
                            .textContentType(.URL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.URL)
                    }
                    field(label: "Port", icon: "number", tint: ThemeColor.blue) {
                        TextField("8765", value: $port, format: .number.grouping(.never))
                            .appFont(size: ThemeTokens.Text.m, design: .monospaced)
                            .textFieldStyle(.plain)
                            .keyboardType(.numberPad)
                    }
                    field(label: "Auth Token", icon: "key.fill", tint: ThemeColor.orange) {
                        SecureField("Auth Token", text: $token)
                            .appFont(size: ThemeTokens.Text.m, design: .monospaced)
                            .textFieldStyle(.plain)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                    field(label: "Name (optional)", icon: "laptopcomputer", tint: ThemeColor.rust) {
                        TextField("My Mac", text: $name)
                            .appFont(size: ThemeTokens.Text.m)
                            .textFieldStyle(.plain)
                            .autocorrectionDisabled()
                    }
                }
                .padding(ThemeTokens.Spacing.m)
            }
            .background(theme.palette.background)
            .themedNavChrome()
            .navigationTitle("Pair manually")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .appFont(size: ThemeTokens.Text.m, weight: .semibold)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        onPayload(
                            OnboardingPairingPayload(
                                host: host,
                                port: port,
                                token: token,
                                name: name.isEmpty ? nil : name
                            )
                        )
                    } label: {
                        Image(systemName: "checkmark")
                            .appFont(size: ThemeTokens.Text.m, weight: .semibold)
                    }
                    .disabled(host.isEmpty || token.isEmpty)
                }
            }
            .preferredColorScheme(theme.palette.colorScheme)
        }
    }

    @ViewBuilder
    private func field<Content: View>(
        label: String, icon: String, tint: Color, @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: ThemeTokens.Spacing.s) {
            Text(label)
                .appFont(size: ThemeTokens.Text.s, weight: .medium)
                .foregroundColor(.secondary)
                .textCase(.uppercase)
            HStack(spacing: ThemeTokens.Spacing.m) {
                Image(systemName: icon)
                    .appFont(size: ThemeTokens.Icon.m)
                    .foregroundColor(tint)
                content()
            }
            .padding(ThemeTokens.Spacing.m)
            .background(theme.palette.surface)
            .clipShape(RoundedRectangle(cornerRadius: ThemeTokens.Radius.l))
        }
    }
}

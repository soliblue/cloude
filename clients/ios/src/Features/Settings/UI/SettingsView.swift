import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(\.theme) private var theme
    @Query(sort: \Endpoint.createdAt) private var endpoints: [Endpoint]
    @State private var accountEndpoint: Endpoint?

    var body: some View {
        List {
            Section {
                SettingsViewEndpoints()
                DaemonUpdateSettingsRow()
                SettingsViewTheme()
            }
            if endpoints.contains(where: { $0.supportsCodex == true }) {
                Section("Codex accounts") {
                    ForEach(endpoints.filter { $0.supportsCodex == true }) { endpoint in
                        Button {
                            accountEndpoint = endpoint
                        } label: {
                            SettingsRow(icon: "person.crop.circle", color: ThemeColor.secondary) {
                                Text(endpoint.displayName)
                                Spacer()
                            }
                        }
                        .foregroundColor(.primary)
                        .accessibilityLabel("Codex account and usage, \(endpoint.displayName)")
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(theme.palette.background)
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .themedNavChrome()
        .sheet(item: $accountEndpoint) { endpoint in
            SessionAccountView(endpoint: endpoint).id("\(endpoint.id)|\(endpoint.connectionRevision?.uuidString ?? "")")
        }
    }
}

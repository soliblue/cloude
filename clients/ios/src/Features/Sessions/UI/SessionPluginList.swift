import SwiftUI

struct SessionPluginList: View {
    let endpoint: Endpoint
    let path: String?
    let threadId: String?
    let installed: Bool
    @State private var store = SessionPluginStore()
    @State private var search = ""
    @Environment(\.theme) private var theme
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        List {
            if installed {
                Section {
                    NavigationLink {
                        SessionPluginList(endpoint: endpoint, path: path, threadId: threadId, installed: false)
                    } label: {
                        Label("Browse plugins", systemImage: "plus.circle")
                    }
                    NavigationLink {
                        SessionAppList(endpoint: endpoint, threadId: threadId)
                    } label: {
                        Label("Apps", systemImage: "app.connected.to.app.below.fill")
                    }
                    NavigationLink {
                        SessionMcpList(endpoint: endpoint, threadId: threadId)
                    } label: {
                        Label("MCP servers", systemImage: "server.rack")
                    }
                } footer: {
                    Text("Connected to \(endpoint.displayName)")
                }
            }
            Section(installed ? "Installed plugins" : "Available plugins") {
                ForEach(
                    store.entries.filter {
                        search.isEmpty || $0.plugin.displayName.localizedCaseInsensitiveContains(search)
                            || $0.plugin.name.localizedCaseInsensitiveContains(search)
                    }
                ) { entry in
                    NavigationLink {
                        SessionPluginDetailView(entry: entry, endpoint: endpoint)
                    } label: {
                        VStack(alignment: .leading, spacing: ThemeTokens.Spacing.xs) {
                            Text(entry.plugin.displayName)
                            if let description = entry.plugin.interface?.shortDescription {
                                Text(description).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                            }
                            Text(
                                entry.plugin.policyDescription
                                    ?? (entry.plugin.installed
                                        ? (entry.plugin.enabled ? "Installed" : "Disabled") : entry.marketplace)
                            )
                            .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                if store.entries.isEmpty && !store.isLoading && store.error == nil {
                    Text(
                        installed ? "No plugins installed on this machine." : "No plugins available from this machine."
                    )
                    .foregroundStyle(.secondary)
                }
            }
            if store.isLoading { ProgressView("Loading plugins…") }
            if let error = store.error {
                Text(error).foregroundStyle(.red)
                Button("Retry") {
                    Task {
                        await SessionPluginService.load(
                            endpoint: endpoint, path: path, installed: installed, store: store, force: true)
                    }
                }
                .disabled(store.isLoading)
            }
        }
        .searchable(text: $search, prompt: "Search plugins")
        .scrollContentBackground(.hidden)
        .background(theme.palette.background)
        .navigationTitle(installed ? "Plugins & apps" : "Browse plugins")
        .navigationBarTitleDisplayMode(.inline)
        .themedNavChrome()
        .task { await SessionPluginService.load(endpoint: endpoint, path: path, installed: installed, store: store) }
        .refreshable {
            await SessionPluginService.load(
                endpoint: endpoint, path: path, installed: installed, store: store, force: true)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task {
                    await SessionPluginService.load(endpoint: endpoint, path: path, installed: installed, store: store)
                }
            }
        }
    }
}

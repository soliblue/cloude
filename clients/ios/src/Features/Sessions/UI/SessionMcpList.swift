import SwiftUI

struct SessionMcpList: View {
    let endpoint: Endpoint
    let threadId: String?
    @State private var store = SessionMcpStore()
    @State private var search = ""
    @Environment(\.theme) private var theme

    var body: some View {
        List {
            Section {
                ForEach(store.servers.filter { search.isEmpty || $0.name.localizedCaseInsensitiveContains(search) }) {
                    server in
                    DisclosureGroup {
                        if server.requiresSignIn {
                            Text("Sign in to this MCP server on \(endpoint.displayName), then refresh this list.").font(
                                .subheadline)
                        }
                        ForEach(server.tools.keys.sorted(), id: \.self) { key in
                            if let tool = server.tools[key] {
                                VStack(alignment: .leading, spacing: ThemeTokens.Spacing.xs) {
                                    Text(tool.name)
                                    if let description = tool.description {
                                        Text(description).font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                        if server.tools.isEmpty { Text("No tools available").foregroundStyle(.secondary) }
                    } label: {
                        VStack(alignment: .leading, spacing: ThemeTokens.Spacing.xs) {
                            Text(server.name)
                            Text(server.status).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            } footer: {
                Text("MCP servers and credentials are configured on the remote machine.")
            }
            if store.isLoading { ProgressView("Loading servers…") }
            if store.nextCursor != nil && !store.isLoading {
                Button("Load more") {
                    Task {
                        await SessionMcpService.load(endpoint: endpoint, threadId: threadId, store: store, more: true)
                    }
                }
            }
            if store.servers.isEmpty && !store.isLoading && store.error == nil {
                Text("No MCP servers configured.").foregroundStyle(.secondary)
            }
            if let error = store.error {
                Text(error).foregroundStyle(.red)
                Button("Retry") {
                    Task { await SessionMcpService.load(endpoint: endpoint, threadId: threadId, store: store) }
                }.disabled(store.isLoading)
            }
        }
        .searchable(text: $search, prompt: "Search servers")
        .scrollContentBackground(.hidden)
        .background(theme.palette.background)
        .navigationTitle("MCP servers")
        .navigationBarTitleDisplayMode(.inline)
        .themedNavChrome()
        .task { await SessionMcpService.load(endpoint: endpoint, threadId: threadId, store: store) }
        .refreshable { await SessionMcpService.load(endpoint: endpoint, threadId: threadId, store: store) }
    }
}

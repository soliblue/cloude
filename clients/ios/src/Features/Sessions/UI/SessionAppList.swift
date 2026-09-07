import SwiftUI

struct SessionAppList: View {
    let endpoint: Endpoint
    let threadId: String?
    @State private var store = SessionAppStore()
    @State private var search = ""
    @Environment(\.theme) private var theme
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        List {
            ForEach(
                store.apps.filter {
                    search.isEmpty
                        || (store.metadata[$0.id]?.name ?? $0.runtimeName ?? $0.id).localizedCaseInsensitiveContains(
                            search)
                }
            ) { app in
                DisclosureGroup {
                    if let metadata = store.metadata[app.id] {
                        if let description = metadata.description { Text(description).font(.subheadline) }
                        ForEach(metadata.toolSummaries ?? []) { tool in
                            VStack(alignment: .leading, spacing: ThemeTokens.Spacing.xs) {
                                Text(tool.title ?? tool.name)
                                Text(tool.description).font(.caption).foregroundStyle(.secondary)
                                if tool.isEnabled == false {
                                    Text(tool.disabledReason ?? "Disabled").font(.caption).foregroundStyle(.secondary)
                                } else if tool.isReadOnly == true {
                                    Text("Read only").font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                    } else {
                        Text("App details are unavailable. Pull to refresh.").foregroundStyle(.secondary)
                    }
                } label: {
                    VStack(alignment: .leading, spacing: ThemeTokens.Spacing.xs) {
                        Text(store.metadata[app.id]?.name ?? app.runtimeName ?? app.id)
                        Text(app.status).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            if store.isLoading { ProgressView("Loading apps…") }
            if store.apps.isEmpty && !store.isLoading && store.error == nil {
                Text("No connected apps are available in this Codex environment.").foregroundStyle(.secondary)
            }
            if let error = store.error {
                Text(error).foregroundStyle(.red)
                Button("Retry") {
                    Task {
                        await SessionAppService.load(endpoint: endpoint, threadId: threadId, store: store, force: true)
                    }
                }.disabled(store.isLoading)
            }
        }
        .searchable(text: $search, prompt: "Search apps")
        .scrollContentBackground(.hidden)
        .background(theme.palette.background)
        .navigationTitle("Apps")
        .navigationBarTitleDisplayMode(.inline)
        .themedNavChrome()
        .task { await SessionAppService.load(endpoint: endpoint, threadId: threadId, store: store) }
        .refreshable { await SessionAppService.load(endpoint: endpoint, threadId: threadId, store: store, force: true) }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await SessionAppService.load(endpoint: endpoint, threadId: threadId, store: store, force: true) }
            }
        }
    }
}

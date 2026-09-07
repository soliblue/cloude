import SwiftUI

struct SessionPluginDetailView: View {
    let entry: SessionPluginEntry
    let endpoint: Endpoint
    @State private var store = SessionPluginDetailStore()
    @State private var confirmingInstall = false
    @State private var confirmingRemoval = false
    @Environment(\.theme) private var theme
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        List {
            if let detail = store.detail {
                Section {
                    if let description = detail.description ?? detail.summary.interface?.longDescription
                        ?? detail.summary.interface?.shortDescription
                    {
                        Text(description).textSelection(.enabled)
                    }
                    if let developer = detail.summary.interface?.developerName {
                        LabeledContent("Developer", value: developer)
                    }
                    LabeledContent("Marketplace", value: entry.marketplace)
                    if let policy = detail.summary.policyDescription { Text(policy).foregroundStyle(.secondary) }
                }
                if !detail.skills.isEmpty {
                    Section("Skills") {
                        ForEach(detail.skills) { skill in
                            VStack(alignment: .leading, spacing: ThemeTokens.Spacing.xs) {
                                Text(skill.name)
                                Text(skill.description).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                if !detail.apps.isEmpty {
                    Section("Apps") { ForEach(detail.apps) { app in Text(app.name) } }
                }
                if !detail.mcpServers.isEmpty {
                    Section("MCP servers") { ForEach(detail.mcpServers, id: \.self) { Text($0) } }
                }
                if !detail.hooks.isEmpty {
                    Section("Hooks") {
                        ForEach(detail.hooks) { hook in Text(hook.eventName).font(.subheadline) }
                        Text("Hooks can run commands on this machine when these events occur.").font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                if let capabilities = detail.summary.interface?.capabilities, !capabilities.isEmpty {
                    Section("Capabilities") { ForEach(capabilities, id: \.self) { Text($0) } }
                }
                if !store.appsNeedingAuth.isEmpty {
                    Section("Connect required apps") {
                        ForEach(store.appsNeedingAuth) { app in
                            if let url = app.installURL {
                                Link("Connect \(app.name)", destination: url)
                            } else {
                                Text("\(app.name) needs a connection. No valid sign-in link was returned.")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Text(
                            "Complete sign-in in your browser, then return to Afto and refresh Apps to check readiness."
                        )
                        .font(.caption).foregroundStyle(.secondary)
                    }
                }
                Section {
                    if store.installed == true {
                        Label("Installed on \(endpoint.displayName)", systemImage: "checkmark.circle")
                        if detail.summary.installPolicySource != "WORKSPACE_SETTING" {
                            Button("Remove plugin", role: .destructive) { confirmingRemoval = true }.disabled(
                                store.isMutating)
                        }
                    } else {
                        Button("Install plugin") {
                            if detail.summary.mustShowInstallationInterstitial == true {
                                confirmingInstall = true
                            } else {
                                Task { await SessionPluginService.install(entry, endpoint: endpoint, store: store) }
                            }
                        }.disabled(!detail.summary.canInstall || store.isMutating || store.isLoading)
                    }
                    if store.isMutating { ProgressView("Updating plugin…") }
                } footer: {
                    Text(
                        "Plugin instructions, tools and hooks are added to Codex on this machine. Review the listed capabilities before installing."
                    )
                }
            }
            if store.isLoading { ProgressView("Loading plugin…") }
            if let error = store.error {
                Text(error).foregroundStyle(.red)
                Button("Refresh status") {
                    Task { await SessionPluginService.detail(entry, endpoint: endpoint, store: store) }
                }.disabled(store.isMutating || store.isLoading)
            }
        }
        .scrollContentBackground(.hidden)
        .background(theme.palette.background)
        .navigationTitle(entry.plugin.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(store.isMutating)
        .interactiveDismissDisabled(store.isMutating)
        .themedNavChrome()
        .task { await SessionPluginService.detail(entry, endpoint: endpoint, store: store) }
        .refreshable { await SessionPluginService.detail(entry, endpoint: endpoint, store: store) }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await SessionPluginService.detail(entry, endpoint: endpoint, store: store) } }
        }
        .confirmationDialog(
            "Install \(entry.plugin.displayName)?", isPresented: $confirmingInstall, titleVisibility: .visible
        ) {
            Button("Install on \(endpoint.displayName)") {
                Task { await SessionPluginService.install(entry, endpoint: endpoint, store: store) }
            }
        } message: {
            Text(
                "This plugin adds the skills, apps, tools and hooks listed on this screen to your remote Codex environment."
            )
        }
        .confirmationDialog(
            "Remove \(entry.plugin.displayName)?", isPresented: $confirmingRemoval, titleVisibility: .visible
        ) {
            Button("Remove plugin", role: .destructive) {
                Task { await SessionPluginService.uninstall(entry, endpoint: endpoint, store: store) }
            }
        } message: {
            Text("Removes this plugin from Codex on \(endpoint.displayName).")
        }
    }
}

import SwiftUI

struct SessionAccountView: View {
    let endpoint: Endpoint
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section(endpoint.displayName) {
                    if let account = ChatAccountStore.shared.accounts[endpoint.id] {
                        Label(
                            account.isSubscription
                                ? "ChatGPT subscription connected"
                                : account.isSignedIn ? "Subscription sign-in required" : "Not signed in",
                            systemImage: account.isSubscription
                                ? "checkmark.shield" : "person.crop.circle.badge.exclamationmark")
                        if let email = account.email { Text(email).textSelection(.enabled) }
                        if let plan = account.plan { LabeledContent("Plan", value: plan.capitalized) }
                        Text("Afto uses your existing Codex subscription. API key billing is not supported.").font(
                            .caption
                        ).foregroundStyle(.secondary)
                    }
                    if let error = ChatAccountStore.shared.errors[endpoint.id] { Text(error).foregroundStyle(.red) }
                    if ChatAccountStore.shared.loading.contains(endpoint.id) { ProgressView("Checking account…") }
                    Button("Refresh") { Task { await ChatAccountService.refresh(endpoint: endpoint) } }
                        .disabled(ChatAccountStore.shared.loading.contains(endpoint.id))
                }
                SessionLoginSection(endpoint: endpoint).id(
                    "\(endpoint.id)|\(endpoint.connectionRevision?.uuidString ?? "")")
                if let account = ChatAccountStore.shared.accounts[endpoint.id] {
                    Section("Subscription usage") {
                        ForEach(account.windows) { window in
                            VStack(alignment: .leading, spacing: ThemeTokens.Spacing.s) {
                                HStack {
                                    Text(window.title)
                                    Spacer()
                                    Text("\(Int(window.remainingPercent.rounded()))% left").monospacedDigit()
                                }
                                .font(.subheadline)
                                ProgressView(value: window.remainingPercent, total: 100)
                                    .tint(window.remainingPercent <= 10 ? .orange : .accentColor)
                                if let reset = window.resetsAt {
                                    Text("Resets \(reset.formatted(date: .abbreviated, time: .shortened))")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            }.padding(.vertical, ThemeTokens.Spacing.xs)
                        }
                        if account.windows.isEmpty {
                            Text("Usage limits are not available from this machine yet.").foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(theme.palette.background)
            .navigationTitle("Codex account")
            .navigationBarTitleDisplayMode(.inline)
            .themedNavChrome()
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .task(id: "\(endpoint.id)|\(endpoint.connectionRevision?.uuidString ?? "")") {
                await ChatAccountService.refresh(endpoint: endpoint)
            }
        }
    }
}

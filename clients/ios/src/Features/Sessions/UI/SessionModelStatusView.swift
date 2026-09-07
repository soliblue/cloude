import SwiftUI

struct SessionModelStatusView: View {
    let session: Session

    var body: some View {
        VStack(alignment: .leading, spacing: ThemeTokens.Spacing.s) {
            if ChatModelCatalog.shared.loading.contains(session.id) { ProgressView("Loading models…").font(.caption) }
            if let error = ChatModelCatalog.shared.errors[session.id] {
                Text(error).font(.caption).foregroundStyle(.secondary)
                Button("Retry model loading") { Task { await ChatModelService.refresh(session: session) } }
            }
            if let endpoint = session.endpoint, let account = ChatAccountStore.shared.accounts[endpoint.id],
                !account.isSubscription
            {
                Label(
                    "Sign in to Codex on this machine with codex login",
                    systemImage: "person.crop.circle.badge.exclamationmark"
                )
                .font(.caption).foregroundStyle(.orange)
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}

import SwiftUI

struct SessionPluginView: View {
    let session: Session
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            if let endpoint = session.endpoint {
                SessionPluginList(
                    endpoint: endpoint, path: session.path, threadId: session.codexThreadId, installed: true
                )
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            }
        }
    }
}

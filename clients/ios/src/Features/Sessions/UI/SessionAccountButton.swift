import SwiftUI

struct SessionAccountButton: View {
    let endpoint: Endpoint
    @State private var showingAccount = false

    var body: some View {
        Button {
            showingAccount = true
        } label: {
            Image(systemName: "person.crop.circle")
        }
        .accessibilityLabel("Codex account and usage")
        .sheet(isPresented: $showingAccount) {
            SessionAccountView(endpoint: endpoint).id("\(endpoint.id)|\(endpoint.connectionRevision?.uuidString ?? "")")
        }
    }
}

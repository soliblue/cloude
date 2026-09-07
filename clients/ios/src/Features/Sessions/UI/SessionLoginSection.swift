import SwiftUI
import UIKit

struct SessionLoginSection: View {
    let endpoint: Endpoint
    @State private var store = SessionLoginStore()
    @Environment(\.modelContext) private var context

    var body: some View {
        Section("ChatGPT sign-in") {
            if store.isPending {
                Text("Sign in on the verification page to connect Codex on \(endpoint.displayName).")
                    .font(.subheadline)
                if let code = store.snapshot?.userCode {
                    HStack {
                        Text(code).font(.title2.monospaced()).textSelection(.enabled)
                        Spacer()
                        Button("Copy code", systemImage: "document.on.document") { UIPasteboard.general.string = code }
                            .labelStyle(.iconOnly)
                            .accessibilityLabel("Copy ChatGPT sign-in code")
                    }
                }
                if let url = store.snapshot?.verificationURL {
                    Link("Open verification page", destination: url)
                } else {
                    Text("The remote machine did not return a valid verification link. Cancel and try again.")
                        .foregroundStyle(.red)
                }
                ProgressView("Waiting for sign-in…")
                Button("Cancel sign-in", role: .destructive) {
                    Task { await SessionLoginService.cancel(endpoint: endpoint, store: store) }
                }.disabled(store.isMutating)
            } else {
                if store.snapshot?.status == "completed" {
                    Label("Sign-in completed", systemImage: "checkmark.circle")
                }
                if store.snapshot?.status == "canceled" { Text("Sign-in canceled").foregroundStyle(.secondary) }
                Button(store.snapshot?.status == "failed" ? "Try sign-in again" : "Sign in with ChatGPT") {
                    Task { await SessionLoginService.start(endpoint: endpoint, store: store) }
                }.disabled(store.isLoading)
                if store.isLoading { ProgressView("Checking sign-in…") }
            }
            if let error = store.error {
                Text(error).foregroundStyle(.red)
                Button("Refresh sign-in status") {
                    Task { await SessionLoginService.refresh(endpoint: endpoint, store: store) }
                }.disabled(store.isLoading)
                Text("You can also run codex login on this machine.").font(.caption).textSelection(.enabled)
            }
            Text("Uses your ChatGPT subscription on this machine. Closing this screen leaves sign-in pending.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .task(id: endpoint.id) { await SessionLoginService.refresh(endpoint: endpoint, store: store) }
        .task(id: "\(endpoint.id)|\(store.isPending)") {
            await SessionLoginService.poll(endpoint: endpoint, store: store)
        }
        .task(id: store.completionId) {
            if store.completionId != nil {
                await SessionLoginService.refreshSignedIn(endpoint: endpoint, context: context)
            }
        }
        .onDisappear { store.invalidate() }
    }
}

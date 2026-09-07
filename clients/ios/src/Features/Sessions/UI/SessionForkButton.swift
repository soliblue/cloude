import SwiftData
import SwiftUI

struct SessionForkButton: View {
    let session: Session
    @Environment(\.modelContext) private var context
    @State private var isForking = false
    @State private var failed = false

    var body: some View {
        Button {
            isForking = true
            Task {
                failed = !(await SessionForkService.fork(session: session, context: context))
                isForking = false
            }
        } label: {
            if isForking {
                ProgressView().controlSize(.small)
            } else {
                Image(systemName: "arrow.triangle.branch")
            }
        }
        .disabled(session.isStreaming || isForking)
        .accessibilityLabel("Start side chat")
        .help("Continue a copy of this conversation in a new chat")
        .alert("Could not start side chat", isPresented: $failed) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Check the connection and make sure the daemon supports Codex thread forks.")
        }
    }
}

import SwiftData
import SwiftUI

struct SessionForkButton: View {
    let session: Session
    @Environment(\.modelContext) private var context
    @State private var store = SessionForkStore()
    @State private var failed = false

    var body: some View {
        Button {
            store.isForking = true
            Task {
                failed = !(await SessionForkService.fork(session: session, context: context, store: store))
            }
        } label: {
            if store.isForking {
                ProgressView().controlSize(.small)
            } else {
                Image(systemName: "arrow.triangle.branch")
            }
        }
        .disabled(
            store.isForking
                || ((session.isStreaming || session.remoteIsRunning)
                    && session.endpoint?.capabilities?.contains("codexActiveFork") != true)
        )
        .accessibilityLabel("Start side chat")
        .help("Start a side chat from the last finished turn")
        .alert("Could not start side chat", isPresented: $failed) {
            if store.unconfirmedRequestId != nil {
                Button("Start another") {
                    Task {
                        failed =
                            !(await SessionForkService.fork(
                                session: session, context: context, store: store, startAnother: true))
                    }
                }
            } else {
                Button("Try again") {
                    Task {
                        failed = !(await SessionForkService.fork(session: session, context: context, store: store))
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(store.error ?? "Could not start side chat.")
        }
    }
}

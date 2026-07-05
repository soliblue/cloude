import SwiftData
import SwiftUI

struct SessionEmptyViewEffortRow: View {
    let session: Session
    @Environment(\.modelContext) private var context
    @AppStorage(StorageKey.defaultChatEffort) private var defaultEffort = ""

    var body: some View {
        SessionEmptyViewPickerRow(
            icon: "brain.head.profile",
            title: "Effort",
            value: session.effort?.displayName ?? "Default"
        ) {
            Button {
                defaultEffort = ""
                SessionActions.setEffort(nil, for: session.id, context: context)
            } label: {
                Label("Default", systemImage: session.effort == nil ? "checkmark" : "")
            }
            ForEach(ChatEffort.allCases, id: \.self) { level in
                Button {
                    defaultEffort = level.rawValue
                    SessionActions.setEffort(level, for: session.id, context: context)
                } label: {
                    Label(level.displayName, systemImage: session.effort == level ? "checkmark" : "")
                }
            }
        }
    }
}

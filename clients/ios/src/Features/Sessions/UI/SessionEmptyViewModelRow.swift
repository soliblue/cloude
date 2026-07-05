import SwiftData
import SwiftUI

struct SessionEmptyViewModelRow: View {
    let session: Session
    @Environment(\.modelContext) private var context
    @AppStorage(StorageKey.defaultChatModel) private var defaultModel = ""

    var body: some View {
        SessionEmptyViewPickerRow(
            icon: "cpu",
            title: "Model",
            value: session.model?.displayName ?? "Auto"
        ) {
            Button {
                defaultModel = ""
                SessionActions.setModel(nil, for: session.id, context: context)
            } label: {
                Label("Auto", systemImage: session.model == nil ? "checkmark" : "")
            }
            ForEach(ChatModel.allCases, id: \.self) { option in
                Button {
                    defaultModel = option.rawValue
                    SessionActions.setModel(option, for: session.id, context: context)
                } label: {
                    Label(option.displayName, systemImage: session.model == option ? "checkmark" : "")
                }
            }
        }
    }
}

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
            value: ChatModelCatalog.shared.displayName(session.model, sessionId: session.id),
            options: options
        )
    }

    private var options: [SessionEmptyViewPickerOption] {
        let auto = SessionEmptyViewPickerOption(
            id: "auto",
            title: "Auto",
            isSelected: session.model == nil,
            action: {
                defaultModel = ""
                SessionActions.setModel(nil, for: session.id, context: context)
            }
        )
        let cases = ChatModelCatalog.shared.models(sessionId: session.id, provider: session.provider).map { model in
            SessionEmptyViewPickerOption(
                id: model.rawValue,
                title: ChatModelCatalog.shared.displayName(model, sessionId: session.id),
                isSelected: session.model == model,
                action: {
                    defaultModel = model.rawValue
                    SessionActions.setModel(model, for: session.id, context: context)
                }
            )
        }
        return [auto] + cases
    }
}

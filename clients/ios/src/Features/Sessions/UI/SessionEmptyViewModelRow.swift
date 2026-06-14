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
            value: session.model?.displayName ?? "Auto",
            options: options
        )
    }

    private var options: [SessionEmptyViewPickerOption] {
        let canSelectAuto = session.canSelectModel(nil)
        let auto = SessionEmptyViewPickerOption(
            id: "auto",
            title: canSelectAuto ? "Auto" : "Auto (new session)",
            isSelected: session.model == nil,
            isEnabled: canSelectAuto,
            action: {
                defaultModel = ""
                SessionActions.setModel(nil, for: session.id, context: context)
            }
        )
        let cases = ChatModel.allCases.map { model in
            let canSelect = session.canSelectModel(model)
            SessionEmptyViewPickerOption(
                id: model.rawValue,
                title: canSelect ? model.displayName : "\(model.displayName) (new session)",
                isSelected: session.model == model,
                isEnabled: canSelect,
                action: {
                    defaultModel = model.rawValue
                    SessionActions.setModel(model, for: session.id, context: context)
                }
            )
        }
        return [auto] + cases
    }
}

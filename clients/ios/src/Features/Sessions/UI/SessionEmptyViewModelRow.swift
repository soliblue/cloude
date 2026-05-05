import SwiftData
import SwiftUI

struct SessionEmptyViewModelRow: View {
    let session: Session
    @Environment(\.modelContext) private var context

    var body: some View {
        SessionEmptyViewPickerRow(
            icon: "cpu",
            title: "Model",
            value: session.model?.displayName ?? "Auto",
            options: options
        )
    }

    private var options: [SessionEmptyViewPickerOption] {
        let auto = SessionEmptyViewPickerOption(
            id: "auto",
            title: "Auto",
            isSelected: session.model == nil,
            action: { SessionActions.setModel(nil, for: session.id, context: context) }
        )
        let cases = ChatModel.allCases.map { model in
            SessionEmptyViewPickerOption(
                id: model.rawValue,
                title: model.displayName,
                isSelected: session.model == model,
                action: { SessionActions.setModel(model, for: session.id, context: context) }
            )
        }
        return [auto] + cases
    }
}

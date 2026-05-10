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
            value: session.effort?.displayName ?? "Default",
            options: options
        )
    }

    private var options: [SessionEmptyViewPickerOption] {
        let defaultOpt = SessionEmptyViewPickerOption(
            id: "default",
            title: "Default",
            isSelected: session.effort == nil,
            action: {
                defaultEffort = ""
                SessionActions.setEffort(nil, for: session.id, context: context)
            }
        )
        let cases = ChatEffort.allCases.map { level in
            SessionEmptyViewPickerOption(
                id: level.rawValue,
                title: level.displayName,
                isSelected: session.effort == level,
                action: {
                    defaultEffort = level.rawValue
                    SessionActions.setEffort(level, for: session.id, context: context)
                }
            )
        }
        return [defaultOpt] + cases
    }
}

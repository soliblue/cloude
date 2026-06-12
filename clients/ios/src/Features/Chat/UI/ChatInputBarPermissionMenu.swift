import SwiftData
import SwiftUI

struct ChatInputBarPermissionMenu: View {
    let sessionId: UUID
    let permissionMode: ChatPermissionMode
    @Environment(\.modelContext) private var context

    var body: some View {
        ForEach(ChatPermissionMode.allCases, id: \.self) { option in
            Button {
                SessionActions.setPermissionMode(option, for: sessionId, context: context)
            } label: {
                Label(
                    option.displayName,
                    systemImage: permissionMode == option ? "checkmark" : option.symbol)
            }
        }
    }
}

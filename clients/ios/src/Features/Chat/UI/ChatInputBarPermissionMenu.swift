import SwiftData
import SwiftUI

struct ChatInputBarPermissionMenu: View {
    let sessionId: UUID
    let provider: ChatProvider
    let permissionMode: ChatPermissionMode
    @Environment(\.modelContext) private var context

    var body: some View {
        ForEach(ChatPermissionMode.allCases.filter { provider == .claude || $0 != .custom }, id: \.self) { option in
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

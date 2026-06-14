import SwiftData
import SwiftUI

struct ChatInputBarModelMenu: View {
    let sessionId: UUID
    let model: ChatModel?
    let effort: ChatEffort?
    @Environment(\.modelContext) private var context

    var body: some View {
        Menu {
            Button {
                SessionActions.setModel(nil, for: sessionId, context: context)
            } label: {
                Label("Auto", systemImage: model == nil ? "checkmark" : "")
            }
            ForEach(ChatModel.allCases, id: \.self) { option in
                Button {
                    SessionActions.setModel(option, for: sessionId, context: context)
                } label: {
                    Label(option.displayName, systemImage: model == option ? "checkmark" : "")
                }
            }
        } label: {
            Label("Model: \(model?.displayName ?? "Auto")", systemImage: model?.symbol ?? "cpu")
        }
        Menu {
            Button {
                SessionActions.setEffort(nil, for: sessionId, context: context)
            } label: {
                Label("Default", systemImage: effort == nil ? "checkmark" : "")
            }
            ForEach(ChatEffort.allCases, id: \.self) { level in
                Button {
                    SessionActions.setEffort(level, for: sessionId, context: context)
                } label: {
                    Label(level.displayName, systemImage: effort == level ? "checkmark" : "")
                }
            }
        } label: {
            Label("Effort: \(effort?.displayName ?? "Default")", systemImage: "brain.head.profile")
        }
    }
}

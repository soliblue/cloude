import SwiftData
import SwiftUI

struct ChatInputBarModelMenu: View {
    let sessionId: UUID
    let provider: ChatProvider
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
            ForEach(ChatModelCatalog.shared.models(sessionId: sessionId, provider: provider), id: \.self) { option in
                Button {
                    SessionActions.setModel(option, for: sessionId, context: context)
                } label: {
                    Label(
                        ChatModelCatalog.shared.displayName(option, sessionId: sessionId),
                        systemImage: model == option ? "checkmark" : "")
                }
            }
        } label: {
            Label(
                "Model: \(ChatModelCatalog.shared.displayName(model, sessionId: sessionId))",
                systemImage: model?.symbol ?? "cpu")
        }
        Menu {
            Button {
                SessionActions.setEffort(nil, for: sessionId, context: context)
            } label: {
                Label("Default", systemImage: effort == nil ? "checkmark" : "")
            }
            ForEach(ChatModelCatalog.shared.efforts(sessionId: sessionId, provider: provider, model: model), id: \.self)
            { level in
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

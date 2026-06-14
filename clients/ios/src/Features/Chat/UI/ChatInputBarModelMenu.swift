import SwiftData
import SwiftUI

struct ChatInputBarModelMenu: View {
    let sessionId: UUID
    let model: ChatModel?
    let effort: ChatEffort?
    let providerLock: ChatModel.Provider?
    @Environment(\.modelContext) private var context

    var body: some View {
        Menu {
            Button {
                SessionActions.setModel(nil, for: sessionId, context: context)
            } label: {
                Label(
                    canSelect(nil) ? "Auto" : "Auto (new session)",
                    systemImage: model == nil ? "checkmark" : "")
            }
            .disabled(!canSelect(nil))
            Section("Claude") {
                ForEach(ChatModel.claudeCases, id: \.self) { option in
                    modelButton(option)
                }
            }
            Section("Codex") {
                ForEach(ChatModel.codexCases, id: \.self) { option in
                    modelButton(option)
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

    private func canSelect(_ option: ChatModel?) -> Bool {
        providerLock.map { (option?.provider ?? .claude) == $0 } ?? true
    }

    private func modelButton(_ option: ChatModel) -> some View {
        Button {
            SessionActions.setModel(option, for: sessionId, context: context)
        } label: {
            Label(
                canSelect(option) ? option.displayName : "\(option.displayName) (new session)",
                systemImage: model == option ? "checkmark" : option.symbol)
        }
        .disabled(!canSelect(option))
    }
}

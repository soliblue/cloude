import SwiftUI
import UIKit

struct ChatInputBarModelMenuButton: UIViewRepresentable {
    let sessionId: UUID
    let provider: ChatProvider
    let model: ChatModel?
    let effort: ChatEffort?
    let onModel: (ChatModel?) -> Void
    let onEffort: (ChatEffort?) -> Void

    func makeUIView(context: Context) -> UIButton {
        let button = UIButton(type: .system)
        button.showsMenuAsPrimaryAction = true
        button.backgroundColor = .clear
        return button
    }

    func updateUIView(_ button: UIButton, context: Context) {
        button.menu = menu
        button.accessibilityLabel = "Choose model and reasoning effort"
        button.accessibilityValue =
            ChatModelCatalog.shared.displayName(model, sessionId: sessionId) + ", "
            + (effort?.displayName ?? "Default effort")
    }

    private var menu: UIMenu {
        let models =
            [UIAction(title: "Auto", state: model == nil ? .on : .off) { _ in onModel(nil) }]
            + ChatModelCatalog.shared.models(sessionId: sessionId, provider: provider).map { option in
                UIAction(
                    title: ChatModelCatalog.shared.displayName(option, sessionId: sessionId),
                    state: model == option ? .on : .off
                ) { _ in
                    onModel(option)
                }
            }
        let efforts =
            [UIAction(title: "Default", state: effort == nil ? .on : .off) { _ in onEffort(nil) }]
            + ChatModelCatalog.shared.efforts(sessionId: sessionId, provider: provider, model: model).map { level in
                UIAction(title: level.displayName, state: effort == level ? .on : .off) { _ in
                    onEffort(level)
                }
            }
        return UIMenu(
            title: "",
            children: [
                UIMenu(
                    title: "Model", subtitle: ChatModelCatalog.shared.displayName(model, sessionId: sessionId),
                    children: models),
                UIMenu(title: "Thinking", subtitle: effort?.displayName ?? "Default", children: efforts),
            ])
    }
}

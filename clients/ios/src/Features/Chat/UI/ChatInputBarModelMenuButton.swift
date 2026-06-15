import SwiftUI
import UIKit

struct ChatInputBarModelMenuButton: UIViewRepresentable {
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
    }

    private var menu: UIMenu {
        let models =
            [UIAction(title: "Auto", state: model == nil ? .on : .off) { _ in onModel(nil) }]
            + ChatModel.allCases.map { option in
                UIAction(title: option.displayName, state: model == option ? .on : .off) { _ in
                    onModel(option)
                }
            }
        let efforts =
            [UIAction(title: "Default", state: effort == nil ? .on : .off) { _ in onEffort(nil) }]
            + ChatEffort.allCases.map { level in
                UIAction(title: level.displayName, state: effort == level ? .on : .off) { _ in
                    onEffort(level)
                }
            }
        return UIMenu(
            title: "",
            children: [
                UIMenu(title: "Model", subtitle: model?.displayName ?? "Auto", children: models),
                UIMenu(title: "Thinking", subtitle: effort?.displayName ?? "Default", children: efforts),
            ])
    }
}

import SwiftUI
import UIKit
import CloudeShared

extension App {
    func handleScreenshot(conversationId: UUID?) {
        DispatchQueue.main.async {
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first(where: { $0.isKeyWindow }) {

                let renderer = UIGraphicsImageRenderer(bounds: window.bounds)
                let image = renderer.image { _ in
                    window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
                }

                if let jpegData = image.jpegData(compressionQuality: 0.7) {
                    let base64 = jpegData.base64EncodedString()

                    let targetConvId = conversationId ?? self.windowManager.activeWindow?.conversation(in: self.conversationStore)?.id
                    if let targetConvId,
                       let conv = self.conversationStore.findConversation(withId: targetConvId) {

                        self.conversationStore.dispatchUserTurn(
                            ChatMessage(kind: .user(), text: "[screenshot]", imageBase64: base64),
                            to: conv,
                            environmentStore: self.environmentStore,
                            imagesBase64: [base64],
                            source: "screenshot send"
                        )
                    }
                }
            }
        }
    }

    func handleHaptic(style: String) {
        let generator: UIImpactFeedbackGenerator
        switch style {
        case "light": generator = UIImpactFeedbackGenerator(style: .light)
        case "heavy": generator = UIImpactFeedbackGenerator(style: .heavy)
        case "rigid": generator = UIImpactFeedbackGenerator(style: .rigid)
        case "soft": generator = UIImpactFeedbackGenerator(style: .soft)
        default: generator = UIImpactFeedbackGenerator(style: .medium)
        }
        generator.impactOccurred()
    }
}

import UIKit

struct ClipboardHelper {
    static func copy(_ text: String, haptic: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
        UIPasteboard.general.string = text
        UIImpactFeedbackGenerator(style: haptic).impactOccurred()
    }
}

import UIKit

@MainActor enum WindowsNotificationPresentation {
    static func dismissPresented(completion: @escaping () -> Void) {
        if let root = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene })
            .flatMap(\.windows).first(where: \.isKeyWindow)?.rootViewController,
            let presented = root.presentedViewController
        {
            if presented.isBeingDismissed || presented.isBeingPresented,
                let transition = presented.transitionCoordinator
            {
                if !transition.animate(
                    alongsideTransition: nil, completion: { _ in dismissPresented(completion: completion) })
                {
                    root.dismiss(animated: true, completion: completion)
                }
            } else {
                root.dismiss(animated: true, completion: completion)
            }
        } else {
            completion()
        }
    }
}

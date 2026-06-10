import SwiftUI

struct OnboardingViewScannerSheetPreview: UIViewControllerRepresentable {
    let onCode: (String) -> Bool
    var onPermissionDenied: (() -> Void)?

    func makeUIViewController(context _: Context) -> OnboardingViewScannerSheetController {
        let controller = OnboardingViewScannerSheetController()
        controller.onCode = onCode
        controller.onPermissionDenied = onPermissionDenied
        return controller
    }

    func updateUIViewController(_: OnboardingViewScannerSheetController, context _: Context) {}
}

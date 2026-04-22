import SwiftData
import SwiftUI

struct OnboardingView: View {
    @Environment(\.theme) private var theme
    @Environment(\.modelContext) private var context
    @State private var store = OnboardingStore()
    let onFinished: (Endpoint) -> Void

    var body: some View {
        ZStack {
            theme.palette.background.ignoresSafeArea()
            switch store.step {
            case .install: OnboardingViewInstallStep(store: store)
            case .pair: OnboardingViewPairStep(store: store)
            case .status: OnboardingViewStatusStep(store: store, onFinished: onFinished)
            }
        }
        .preferredColorScheme(theme.palette.colorScheme)
        .onReceive(NotificationCenter.default.publisher(for: .deeplinkPair)) { notification in
            if let payload = notification.object as? OnboardingPairingPayload {
                store.apply(payload: payload)
            }
        }
    }
}

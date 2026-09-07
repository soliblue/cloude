import SwiftData
import SwiftUI

struct OnboardingView: View {
    @Environment(\.theme) private var theme
    @Environment(\.modelContext) private var context
    @State private var store: OnboardingStore
    let onCancel: (() -> Void)?
    let onFinished: (Endpoint) -> Void

    init(
        initialStep: OnboardingStep = .install, onCancel: (() -> Void)? = nil,
        onFinished: @escaping (Endpoint) -> Void
    ) {
        _store = State(initialValue: OnboardingStore(step: initialStep))
        self.onCancel = onCancel
        self.onFinished = onFinished
    }

    var body: some View {
        ZStack {
            theme.palette.background.ignoresSafeArea()
            GeometryReader { geometry in
                ScrollView {
                    Group {
                        switch store.step {
                        case .install: OnboardingViewInstallStep(store: store)
                        case .pair: OnboardingViewPairStep(store: store)
                        case .status: OnboardingViewStatusStep(store: store, onFinished: onFinished)
                        }
                    }
                    .frame(minHeight: geometry.size.height)
                }
                .scrollBounceBehavior(.basedOnSize)
                .id(store.step)
            }
            if let onCancel {
                VStack {
                    HStack {
                        Spacer()
                        Button(action: onCancel) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: ThemeTokens.Icon.xl))
                                .foregroundStyle(ThemeColor.secondary)
                        }
                        .frame(width: 44, height: 44)
                        .accessibilityLabel("Close setup")
                    }
                    Spacer()
                }
                .padding(ThemeTokens.Spacing.l)
            }
        }
        .preferredColorScheme(theme.palette.colorScheme)
        .onAppear {
            if let payload = DeepLinkRouter.consumePendingPair() {
                store.apply(payload: payload)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .deeplinkPair)) { notification in
            if let payload = notification.object as? OnboardingPairingPayload {
                _ = DeepLinkRouter.consumePendingPair()
                store.apply(payload: payload)
            }
        }
    }
}

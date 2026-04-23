import SwiftUI

struct OnboardingViewPairStep: View {
    let store: OnboardingStore
    @Environment(\.theme) private var theme
    @Environment(\.appAccent) private var appAccent
    @State private var isManualPresented = false
    @State private var isUnrecognized = false
    @State private var isPermissionDenied = false

    private var subtitle: String {
        if isPermissionDenied {
            return "Camera access is off. Enable it in Settings, or pair manually."
        }
        if isUnrecognized {
            return "That QR isn't a pairing code. Try again."
        }
        return "Point your camera at the QR shown in Remote CC Daemon."
    }

    var body: some View {
        VStack(alignment: .leading, spacing: ThemeTokens.Spacing.l) {
            Spacer()
            VStack(alignment: .leading, spacing: ThemeTokens.Spacing.s) {
                Text("Scan the pairing QR")
                    .appFont(size: ThemeTokens.Text.xxl, weight: .semibold)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(subtitle)
                    .appFont(size: ThemeTokens.Text.xl)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: 520, alignment: .leading)
            }
            OnboardingViewScannerSheetPreview(
                onCode: { code in
                    if let url = URL(string: code),
                        let payload = OnboardingPairingPayload(url: url)
                    {
                        store.apply(payload: payload)
                    } else {
                        isUnrecognized = true
                    }
                },
                onPermissionDenied: { isPermissionDenied = true }
            )
            .clipShape(RoundedRectangle(cornerRadius: ThemeTokens.Radius.m, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: ThemeTokens.Radius.m, style: .continuous)
                    .strokeBorder(
                        Color.white.opacity(ThemeTokens.Opacity.l),
                        style: StrokeStyle(lineWidth: ThemeTokens.Stroke.s, dash: [10, 8])
                    )
            }
            .aspectRatio(1, contentMode: .fit)
            .frame(maxWidth: .infinity)
            Button {
                isManualPresented = true
            } label: {
                Text("Enter manually")
                    .appFont(size: ThemeTokens.Text.l, weight: .semibold)
                    .foregroundColor(appAccent.color)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
            Spacer()
        }
        .padding(ThemeTokens.Spacing.l)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.palette.background.ignoresSafeArea())
        .sheet(isPresented: $isManualPresented) {
            OnboardingViewManualSheet { payload in
                isManualPresented = false
                store.apply(payload: payload)
            }
        }
    }
}

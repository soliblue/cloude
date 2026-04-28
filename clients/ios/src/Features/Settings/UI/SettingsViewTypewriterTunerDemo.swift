import SwiftUI

struct SettingsViewTypewriterTunerDemo: View {
    let source: String
    let replayToken: Int
    @AppStorage(StorageKey.typewriterCps) private var cps: Double = TypewriterDefaults.cps
    @AppStorage(StorageKey.typewriterFadeWindow) private var fadeWindow: Double = TypewriterDefaults
        .fadeWindow
    @State private var revealedGlyphs: Double = 0
    @State private var ticker: Task<Void, Never>?

    var body: some View {
        Text(source)
            .appFont(size: ThemeTokens.Text.m)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .textRenderer(
                ChatTypewriterTextRenderer(
                    revealedGlyphs: revealedGlyphs, fadeWindow: fadeWindow))
            .onAppear { startTicker() }
            .onDisappear {
                ticker?.cancel()
                ticker = nil
            }
            .onChange(of: replayToken) { _, _ in revealedGlyphs = 0 }
    }

    private func startTicker() {
        ticker?.cancel()
        ticker = Task { @MainActor in
            let frame: Double = 1.0 / 60.0
            let total = Double(source.count)
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(16))
                if revealedGlyphs >= total {
                    try? await Task.sleep(for: .milliseconds(1500))
                    revealedGlyphs = 0
                    continue
                }
                revealedGlyphs = min(total, revealedGlyphs + cps * frame)
            }
        }
    }
}

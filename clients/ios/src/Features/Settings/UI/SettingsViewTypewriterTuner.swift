import SwiftUI

struct SettingsViewTypewriterTuner: View {
    @Environment(\.theme) private var theme
    @AppStorage(StorageKey.typewriterCps) private var cps: Double = TypewriterDefaults.cps
    @AppStorage(StorageKey.typewriterFadeWindow) private var fadeWindow: Double = TypewriterDefaults
        .fadeWindow
    @AppStorage(StorageKey.typewriterSlide) private var slide: Double = TypewriterDefaults.slide
    @State private var replayToken: Int = 0

    private let demoText: String =
        "The quick brown fox jumps over the lazy dog while a steady ticker drains the buffer at the speed you set, fading and sliding each character into place."

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: ThemeTokens.Spacing.l) {
                sectionHeader("Live demo")
                VStack(alignment: .leading, spacing: ThemeTokens.Spacing.m) {
                    SettingsViewTypewriterTunerDemo(source: demoText, replayToken: replayToken)
                        .padding(ThemeTokens.Spacing.m)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(theme.palette.surface)
                        .cornerRadius(ThemeTokens.Radius.m)
                    Button {
                        replayToken &+= 1
                    } label: {
                        Label("Replay", systemImage: "arrow.clockwise")
                            .appFont(size: ThemeTokens.Text.m, weight: .medium)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(theme.palette.accent)
                }

                sectionHeader("Reveal speed")
                sliderRow(
                    value: $cps, range: 10...300, step: 5,
                    formatted: "\(Int(cps)) chars/sec",
                    caption: "How fast the buffer drains.")

                sectionHeader("Fade window")
                sliderRow(
                    value: $fadeWindow, range: 1...60, step: 1,
                    formatted: "\(Int(fadeWindow)) glyphs",
                    caption: "Number of trailing characters mid-fade. Wider = softer leading edge.")

                sectionHeader("Slide distance")
                sliderRow(
                    value: $slide, range: 0...40, step: 1,
                    formatted: "\(Int(slide)) pt",
                    caption: "How far each character slides in from the left.")

                Button {
                    cps = TypewriterDefaults.cps
                    fadeWindow = TypewriterDefaults.fadeWindow
                    slide = TypewriterDefaults.slide
                    replayToken &+= 1
                } label: {
                    Text("Reset to defaults")
                        .appFont(size: ThemeTokens.Text.m, weight: .medium)
                        .foregroundColor(ThemeColor.danger)
                }
                .buttonStyle(.plain)
                .padding(.top, ThemeTokens.Spacing.l)
            }
            .padding(.horizontal, ThemeTokens.Spacing.m)
            .padding(.vertical, ThemeTokens.Spacing.m)
        }
        .themedNavChrome()
    }

    private func sliderRow(
        value: Binding<Double>, range: ClosedRange<Double>, step: Double,
        formatted: String, caption: String
    ) -> some View {
        VStack(alignment: .leading, spacing: ThemeTokens.Spacing.xs) {
            HStack {
                Slider(value: value, in: range, step: step)
                Text(formatted)
                    .appFont(size: ThemeTokens.Text.s, weight: .medium)
                    .monospacedDigit()
                    .foregroundColor(.secondary)
                    .frame(minWidth: 80, alignment: .trailing)
            }
            Text(caption)
                .appFont(size: ThemeTokens.Text.s)
                .foregroundColor(.secondary)
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .appFont(size: ThemeTokens.Text.s, weight: .medium)
            .foregroundColor(.secondary)
            .textCase(.uppercase)
    }
}

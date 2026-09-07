import SwiftUI
import UIKit

struct LiteralTextField: View {
    let title: String
    @Binding var text: String
    var focused: Binding<Bool>?
    var lines: ClosedRange<Int> = 1...6
    var fontSize: CGFloat = 17
    @State private var localFocus = false
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.fontStep) private var fontStep
    @Environment(\.appAccent) private var appAccent
    @ScaledMetric(relativeTo: .body) private var scale = 1.0

    var body: some View {
        ZStack(alignment: .topLeading) {
            if text.isEmpty {
                Text(title)
                    .font(.system(size: (fontSize + fontStep) * scale))
                    .foregroundStyle(Color(uiColor: .placeholderText))
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
            LiteralTextInput(
                text: $text, focused: focused ?? $localFocus, label: title, lines: lines,
                font: .systemFont(ofSize: (fontSize + fontStep) * scale),
                tint: UIColor(appAccent.color), enabled: isEnabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

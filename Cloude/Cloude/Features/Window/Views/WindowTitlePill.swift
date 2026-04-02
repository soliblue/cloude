import SwiftUI
import CloudeShared

struct WindowTitlePill: View {
    let symbol: String?

    var body: some View {
        Image.safeSymbol(symbol, fallback: "bubble.left.fill")
            .font(.system(size: DS.Icon.m, weight: .medium))
            .foregroundColor(.secondary)
    }
}

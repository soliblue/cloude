import SwiftUI

struct WindowSwitcherStaticLabel: View {
    let symbol: String
    let name: String
    let isActive: Bool
    let useSymbols: Bool
    let isStreaming: Bool

    var body: some View {
        let color: Color = isActive ? .accentColor : (isStreaming ? .accentColor : .secondary)

        if useSymbols {
            Image(systemName: symbol)
                .font(.system(size: DS.Icon.l, weight: isActive ? .semibold : .regular))
                .foregroundStyle(color)
                .modifier(StreamingPulseModifier(isStreaming: isStreaming))
        } else {
            Text(name)
                .font(.system(size: DS.Text.l, weight: isActive ? .semibold : .regular))
                .foregroundStyle(color)
                .lineLimit(1)
                .truncationMode(.middle)
                .modifier(StreamingPulseModifier(isStreaming: isStreaming))
        }
    }
}

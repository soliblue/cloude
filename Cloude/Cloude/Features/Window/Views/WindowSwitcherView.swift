import SwiftUI

struct WindowSwitcherView: View {
    let items: [WindowSwitcherEntry]
    let activeId: UUID?
    let appTheme: AppTheme
    let onSelect: (UUID) -> Void
    let onLongPress: (UUID) -> Void

    var body: some View {
        #if DEBUG
        let _ = DebugMetrics.log("WindowSwitcher", "render | windows=\(items.count) active=\(activeId?.uuidString.prefix(6) ?? "nil")")
        #endif
        HStack(spacing: DS.Spacing.s) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                let isActive = activeId == item.id

                if index > 0 {
                    Divider().frame(height: DS.Icon.l)
                }

                Button {
                    onSelect(item.id)
                } label: {
                    WindowSwitcherLabel(
                        symbol: item.symbol,
                        name: item.name,
                        isActive: isActive,
                        useSymbols: items.count >= 3,
                        output: item.output
                    )
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .agenticID("window_picker_\(index)")
                .buttonStyle(.plain)
                .simultaneousGesture(
                    LongPressGesture().onEnded { _ in
                        onLongPress(item.id)
                    }
                )
            }

        }
        .padding(.horizontal, DS.Spacing.m)
        .frame(maxWidth: .infinity)
        .background(Color.themeBackground(appTheme))
    }
}

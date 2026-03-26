import SwiftUI

struct WindowTabBar: View {
    let activeType: WindowType
    let envConnected: Bool
    let onSelectType: (WindowType) -> Void

    var body: some View {
        HStack(spacing: 0) {
            #if DEBUG
            let _ = DebugMetrics.log("WindowTabBar", "render | type=\(activeType) envConn=\(envConnected)")
            #endif
            ForEach(Array(WindowType.allCases.enumerated()), id: \.element) { index, type in
                let enabled = type == .chat || envConnected
                if index > 0 {
                    Divider()
                        .frame(height: DS.Icon.m)
                }
                Button(action: {
                    if enabled { onSelectType(type) }
                }) {
                    Image(systemName: type.icon)
                        .font(.system(size: DS.Icon.m, weight: activeType == type ? .semibold : .regular))
                        .foregroundColor(activeType == type ? .accentColor : .secondary)
                        .opacity(enabled ? 1 : DS.Opacity.strong)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DS.Spacing.s)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(0)
        .background(Color.themeSecondary)
    }
}

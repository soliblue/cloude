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
                        .frame(height: DS.Icon.tab)
                }
                Button(action: {
                    if enabled { onSelectType(type) }
                }) {
                    Image(systemName: type.icon)
                        .font(.system(size: DS.Icon.tab, weight: activeType == type ? .semibold : .regular))
                        .foregroundColor(activeType == type ? .accentColor : .secondary)
                        .opacity(enabled ? 1 : 0.3)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 7)
        .padding(.top, 0)
        .padding(.bottom, 7)
        .background(Color.themeSecondary)
    }
}

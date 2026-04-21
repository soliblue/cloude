import SwiftData
import SwiftUI

struct WindowsView: View {
    @Environment(\.theme) private var theme
    @Query(sort: \Window.order) private var windows: [Window]

    var body: some View {
        ZStack(alignment: .topTrailing) {
            theme.palette.background.ignoresSafeArea()
            ZStack {
                ForEach(windows) { window in
                    if let session = window.session {
                        SessionView(session: session)
                            .opacity(window.isFocused ? 1 : 0)
                            .allowsHitTesting(window.isFocused)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .safeAreaInset(edge: .bottom) {
                WindowsViewSwitcher()
            }
            DebugOverlay()
        }
        .preferredColorScheme(theme.palette.colorScheme)
    }
}

import SwiftData
import SwiftUI

struct SessionsMenuButton: View {
    let action: () -> Void
    @Query(sort: \Window.order) private var windows: [Window]
    @Environment(\.appAccent) private var appAccent
    @State private var unreadCount = 0

    var body: some View {
        IconPillButton(symbol: "line.3.horizontal", action: action)
            .overlay(alignment: .topTrailing) {
                if unreadCount > 0 {
                    Text("\(unreadCount)")
                        .appFont(size: ThemeTokens.Text.s, weight: .semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, ThemeTokens.Spacing.xs)
                        .frame(minWidth: 18, minHeight: 18)
                        .background(Capsule().fill(appAccent.color))
                        .offset(x: 6, y: -6)
                }
            }
            .background {
                ForEach(unreadWindows) { window in
                    if let session = window.session {
                        SessionUnreadProbe(session: session)
                    }
                }
                .onPreferenceChange(UnreadCountPreferenceKey.self) { unreadCount = $0 }
            }
    }

    private var unreadWindows: [Window] {
        windows.filter { !$0.isFocused }
    }
}

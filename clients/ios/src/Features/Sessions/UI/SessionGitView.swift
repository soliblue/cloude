import SwiftUI

struct SessionGitView: View {
    @Bindable var session: Session
    let openSidebar: () -> Void
    let openChat: () -> Void

    var body: some View {
        GitView(session: session)
            .safeAreaInset(edge: .top, spacing: 0) {
                SessionGitHeader(session: session, openSidebar: openSidebar, openChat: openChat)
            }
    }
}

import SwiftUI

struct SessionGitView: View {
    @Bindable var session: Session

    var body: some View {
        GitView(session: session)
    }
}

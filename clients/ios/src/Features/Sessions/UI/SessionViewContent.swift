import SwiftUI

struct SessionViewContent: View {
    let session: Session
    @Binding var folderPickerRequest: SessionFolderPickerRequest?

    var body: some View {
        if session.isConfigured {
            if session.tab == .chat {
                ChatView(session: session, folderPickerRequest: $folderPickerRequest)
            } else if session.tab == .files {
                FileTreeView(session: session)
            } else if session.hasGit {
                GitView(session: session)
            }
        } else {
            ChatView(session: session, folderPickerRequest: $folderPickerRequest)
        }
    }
}

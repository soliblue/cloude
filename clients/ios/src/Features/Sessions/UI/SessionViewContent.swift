import SwiftUI

struct SessionViewContent: View {
    let session: Session
    let selectedTab: SessionTab
    @Binding var folderPickerRequest: SessionFolderPickerRequest?

    var body: some View {
        if session.isConfigured {
            if selectedTab == .files {
                FileTreeView(session: session)
            } else {
                ChatView(session: session, folderPickerRequest: $folderPickerRequest)
            }
        } else {
            ChatView(session: session, folderPickerRequest: $folderPickerRequest)
        }
    }
}

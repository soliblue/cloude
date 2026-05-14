import SwiftUI

struct SessionViewContent: View {
    let session: Session
    @Binding var folderPickerRequest: SessionFolderPickerRequest?

    var body: some View {
        ChatView(session: session, folderPickerRequest: $folderPickerRequest)
    }
}

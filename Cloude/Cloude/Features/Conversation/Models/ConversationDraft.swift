import Foundation

struct ConversationDraft {
    var text = ""
    var images: [AttachedImage] = []
    var files: [AttachedFile] = []

    var isEmpty: Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && images.isEmpty && files.isEmpty
    }
}

import Foundation

struct SessionFolderPickerRequest: Equatable, Identifiable {
    let id = UUID()
    let sessionId: UUID
    let endpointId: UUID
}

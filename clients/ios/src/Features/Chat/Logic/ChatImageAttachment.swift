import Foundation

struct ChatImageAttachment: Identifiable, Equatable {
    let id: UUID
    let data: Data

    init(data: Data) {
        self.id = UUID()
        self.data = data
    }

    init(id: UUID = UUID(), data: Data) {
        self.id = id
        self.data = data
    }
}

import Foundation

struct ChatToolChip: Identifiable {
    let icon: String
    let label: String
    var id: String { label }
}

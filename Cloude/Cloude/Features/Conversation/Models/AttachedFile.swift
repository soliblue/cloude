import Foundation

struct AttachedFile: Identifiable {
    let id = UUID()
    let name: String
    let data: Data
}

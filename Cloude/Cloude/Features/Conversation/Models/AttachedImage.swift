import Foundation

struct AttachedImage: Identifiable {
    let id = UUID()
    let data: Data
    let isScreenshot: Bool
}

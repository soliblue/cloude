import Foundation

struct Draft {
    let text: String
    let images: [AttachedImage]
    let effort: EffortLevel?
    let model: ModelSelection?
}

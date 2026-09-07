import Foundation

nonisolated struct ChatAccountSnapshot {
    let email: String?
    let plan: String?
    let isSubscription: Bool
    let isSignedIn: Bool
    let windows: [ChatUsageWindow]
}

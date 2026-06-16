import Foundation

struct DaemonUpdateShareItems: Identifiable {
    let id = UUID()
    let items: [Any]
}

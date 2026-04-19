import Foundation
import CloudeShared

extension WindowManager {
    func save() {
        UserDefaults.standard.setCodable(windows, forKey: windowsKey)
        if let activeId = activeWindowId {
            UserDefaults.standard.set(activeId.uuidString, forKey: activeKey)
        }
    }

    func load() {
        windows = UserDefaults.standard.codable([Window].self, forKey: windowsKey, default: [])
        if let idString = UserDefaults.standard.string(forKey: activeKey),
           let id = UUID(uuidString: idString),
           windows.contains(where: { $0.id == id }) {
            activeWindowId = id
        }
    }
}

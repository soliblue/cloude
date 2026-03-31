import SwiftUI
import CloudeShared

extension CloudeApp {
    func selectWindow(index: Int) {
        guard index >= 0 && index < windowManager.windows.count else {
            AppLogger.bootstrapInfo("select window ignored index=\(index) count=\(windowManager.windows.count)")
            return
        }
        windowManager.navigateToWindow(at: index)
        AppLogger.bootstrapInfo("selected window index=\(index)")
    }

    func closeActiveWindow() {
        guard let activeWindow = windowManager.activeWindow else {
            AppLogger.bootstrapInfo("close window ignored no active window")
            return
        }
        if let overridePath = fileBrowserRootOverrides.removeValue(forKey: activeWindow.id) {
            AppLogger.bootstrapInfo("cleared file override windowId=\(activeWindow.id.uuidString) path=\(overridePath)")
        }
        if let overridePath = gitRepoRootOverrides.removeValue(forKey: activeWindow.id) {
            AppLogger.bootstrapInfo("cleared git override windowId=\(activeWindow.id.uuidString) path=\(overridePath)")
        }
        guard windowManager.canRemoveWindow else {
            AppLogger.bootstrapInfo("close window ignored only one window")
            return
        }
        windowManager.removeWindow(activeWindow.id)
        AppLogger.bootstrapInfo("closed window id=\(activeWindow.id.uuidString)")
    }

    func createWindow(type: WindowType? = nil) {
        let newWindowId = windowManager.addWindow()
        if let type {
            windowManager.setWindowType(newWindowId, type: type)
        }
        AppLogger.bootstrapInfo("created window id=\(newWindowId.uuidString) type=\((type ?? .chat).rawValue)")
    }

    func setActiveWindowType(_ type: WindowType) {
        if windowManager.activeWindow == nil {
            windowManager.addWindow()
        }
        guard let activeWindow = windowManager.activeWindow else { return }
        windowManager.setWindowType(activeWindow.id, type: type)
        AppLogger.bootstrapInfo("set active window type windowId=\(activeWindow.id.uuidString) type=\(type.rawValue)")
    }
}

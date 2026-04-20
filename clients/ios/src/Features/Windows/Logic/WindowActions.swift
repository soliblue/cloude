import Foundation
import SwiftData

enum WindowActions {
    @MainActor
    static func ensureOne(context: ModelContext) {
        let windows = (try? context.fetch(FetchDescriptor<Window>())) ?? []
        if windows.isEmpty {
            spawn(order: 0, focused: true, context: context)
        }
    }

    @MainActor
    static func activate(_ window: Window, among windows: [Window]) {
        windows.forEach { $0.isFocused = ($0.id == window.id) }
    }

    @MainActor
    static func addNew(into context: ModelContext, after windows: [Window]) {
        let nextOrder = (windows.map(\.order).max() ?? -1) + 1
        windows.forEach { $0.isFocused = false }
        spawn(order: nextOrder, focused: true, context: context)
    }

    @MainActor
    static func close(_ window: Window, among windows: [Window], context: ModelContext) {
        if windows.count > 1 {
            let wasFocused = window.isFocused
            let remaining = windows.filter { $0.id != window.id }
            context.delete(window)
            if wasFocused {
                remaining.first?.isFocused = true
            }
        }
    }

    @MainActor
    private static func spawn(order: Int, focused: Bool, context: ModelContext) {
        let session = SessionActions.add(into: context)
        context.insert(Window(session: session, order: order, isFocused: focused))
    }
}

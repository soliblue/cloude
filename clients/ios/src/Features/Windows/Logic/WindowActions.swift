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
        if let session = window.session {
            SessionActions.markOpened(session)
        }
    }

    @MainActor
    @discardableResult
    static func addNew(
        into context: ModelContext,
        after windows: [Window],
        endpoint: Endpoint? = nil
    ) -> Session {
        let nextOrder = (windows.map(\.order).max() ?? -1) + 1
        let inherited = endpoint == nil ? windows.first(where: { $0.isFocused })?.session : nil
        windows.forEach { $0.isFocused = false }
        return spawn(
            order: nextOrder,
            focused: true,
            endpoint: endpoint ?? inherited?.endpoint,
            path: inherited?.path,
            context: context
        )
    }

    @MainActor
    static func open(_ session: Session, among windows: [Window], context: ModelContext) {
        let nextOrder = (windows.map(\.order).max() ?? -1) + 1
        windows.forEach { $0.isFocused = false }
        SessionActions.markOpened(session)
        context.insert(Window(session: session, order: nextOrder, isFocused: true))
    }

    @MainActor
    static func swap(_ window: Window, to target: Session, context: ModelContext) {
        let current = window.session
        window.session = target
        SessionActions.markOpened(target)
        if let current, current.id != target.id {
            SessionActions.deleteIfEmpty(current, context: context)
        }
    }

    @MainActor
    static func close(_ window: Window, among windows: [Window], context: ModelContext) {
        if windows.count > 1 {
            let wasFocused = window.isFocused
            let ordered = windows.sorted(by: { $0.order < $1.order })
            let closedIndex = ordered.firstIndex(where: { $0.id == window.id }) ?? 0
            let remaining = ordered.filter { $0.id != window.id }
            context.delete(window)
            if wasFocused, !remaining.isEmpty {
                let neighborIndex = min(remaining.count - 1, max(0, closedIndex - 1))
                remaining[neighborIndex].isFocused = true
            }
        }
    }

    @MainActor
    @discardableResult
    private static func spawn(
        order: Int,
        focused: Bool,
        endpoint: Endpoint? = nil,
        path: String? = nil,
        context: ModelContext
    ) -> Session {
        let session = SessionActions.add(into: context, endpoint: endpoint, path: path)
        context.insert(Window(session: session, order: order, isFocused: focused))
        return session
    }
}

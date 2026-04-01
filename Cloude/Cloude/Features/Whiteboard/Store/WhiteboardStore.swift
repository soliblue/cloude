// WhiteboardStore.swift

import Foundation
import SwiftUI
import Combine

@MainActor
class WhiteboardStore: ObservableObject {
    @Published var isPresented = false
    @Published var state = WhiteboardState()
    @Published var selectedElementIds: Set<String> = []
    var selectedElementId: String? { selectedElementIds.first }
    @Published var activeTool: ActiveTool = .hand
    @Published var activeColor: String = "#FFFFFF"

    @Published var arrowSourceId: String?

    enum ActiveTool {
        case hand
        case multiSelect
        case rect
        case ellipse
        case triangle
        case text
        case pencil
        case arrow
    }

    var undoStack: [[WhiteboardElement]] = []
    var redoStack: [[WhiteboardElement]] = []
    let maxUndoLevels = 50
    var saveDebounce: Task<Void, Never>?
    var currentConversationId: UUID?
    var inTransaction = false

    static var storageDir: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("whiteboards")
    }

    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }

    func present(conversationId: UUID?) {
        load(conversationId: conversationId)
        isPresented = true
    }

    func scale(for canvasSize: CGSize) -> CGFloat {
        canvasSize.width / 1000.0 * state.viewport.zoom
    }

    func beginTransaction() {
        if !inTransaction {
            undoStack.append(state.elements)
            if undoStack.count > maxUndoLevels {
                undoStack.removeFirst()
            }
            redoStack.removeAll()
            inTransaction = true
        }
    }

    func commitTransaction() {
        inTransaction = false
        scheduleSave()
    }

    func pushUndoSnapshot() {
        if inTransaction { return }
        undoStack.append(state.elements)
        if undoStack.count > maxUndoLevels {
            undoStack.removeFirst()
        }
        redoStack.removeAll()
        scheduleSave()
    }

    func mutateElement(id: String, _ mutation: (inout WhiteboardElement) -> Void) {
        if let index = state.elements.firstIndex(where: { $0.id == id }) {
            pushUndoSnapshot()
            mutation(&state.elements[index])
        }
    }

    func undo() {
        if let previous = undoStack.popLast() {
            redoStack.append(state.elements)
            state.elements = previous
            selectedElementIds.removeAll()
            scheduleSave()
        }
    }

    func redo() {
        if let next = redoStack.popLast() {
            undoStack.append(state.elements)
            state.elements = next
            selectedElementIds.removeAll()
            scheduleSave()
        }
    }
}

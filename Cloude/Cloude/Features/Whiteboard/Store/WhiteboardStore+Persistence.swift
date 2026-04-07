import Foundation

extension WhiteboardStore {
    func load(conversationId: UUID?) {
        currentConversationId = conversationId
        if let convId = conversationId {
            let url = Self.storageDir.appendingPathComponent("\(convId.uuidString).json")
            if let data = try? Data(contentsOf: url),
               let loaded = try? JSONDecoder().decode(WhiteboardState.self, from: data) {
                state = loaded
                undoStack.removeAll()
                redoStack.removeAll()
                selectedElementIds.removeAll()
                return
            }
        }
        state = WhiteboardState()
        undoStack.removeAll()
        redoStack.removeAll()
        selectedElementIds.removeAll()
    }

    func scheduleSave() {
        saveDebounce?.cancel()
        saveDebounce = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(500))
            if !Task.isCancelled { save() }
        }
    }

    private func save() {
        if let convId = currentConversationId {
            let dir = Self.storageDir
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            if let data = try? JSONEncoder().encode(state) {
                try? data.write(to: dir.appendingPathComponent("\(convId.uuidString).json"))
            }
        }
    }
}

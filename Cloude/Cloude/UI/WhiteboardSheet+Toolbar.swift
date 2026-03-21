// WhiteboardSheet+Toolbar.swift

import SwiftUI

extension WhiteboardSheet {
    @ToolbarContentBuilder
    var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            HStack(spacing: 12) {
                Button(action: { store.undo() }) {
                    Image(systemName: "arrow.uturn.backward")
                        .foregroundColor(store.canUndo ? .primary : .secondary.opacity(0.3))
                }
                .disabled(!store.canUndo)

                Button(action: { store.redo() }) {
                    Image(systemName: "arrow.uturn.forward")
                        .foregroundColor(store.canRedo ? .primary : .secondary.opacity(0.3))
                }
                .disabled(!store.canRedo)
            }
        }

        ToolbarItem(placement: .topBarTrailing) {
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
            }
        }
    }

    @ViewBuilder
    var floatingToolbar: some View {
        VStack(spacing: 8) {
            if store.selectedElementId != nil && store.activeTool == .hand {
                contextBar
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            if store.activeTool != .hand {
                colorBar
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            toolBar
        }
        .animation(.easeInOut(duration: 0.2), value: store.activeTool)
        .animation(.easeInOut(duration: 0.2), value: store.selectedElementId != nil)
    }

    private var toolBar: some View {
        HStack(spacing: 0) {
            toolButton(icon: "hand.draw", tool: .hand)
            toolButton(icon: "rectangle", tool: .rect)
            toolButton(icon: "circle", tool: .ellipse)
            toolButton(icon: "textformat", tool: .text)
            toolButton(icon: "pencil.tip", tool: .pencil)
            toolButton(icon: "arrow.right", tool: .arrow)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
    }

    private func toolButton(icon: String, tool: WhiteboardStore.ActiveTool) -> some View {
        Button(action: {
            if store.activeTool == tool && tool != .hand {
                store.activeTool = .hand
            } else {
                store.activeTool = tool
            }
            store.arrowSourceId = nil
            if tool != .hand {
                store.selectedElementId = nil
            }
        }) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .frame(width: 44, height: 36)
                .background(store.activeTool == tool ? Color.accentColor.opacity(0.2) : Color.clear)
                .cornerRadius(8)
                .foregroundColor(store.activeTool == tool ? .accentColor : .primary.opacity(0.7))
        }
        .buttonStyle(.plain)
    }

    static let paletteColors = ["#FFFFFF", "#FF6B6B", "#4ECDC4", "#FFE66D", "#A78BFA", "#FF8C42"]

    private var colorBar: some View {
        HStack(spacing: 10) {
            ForEach(Self.paletteColors, id: \.self) { hex in
                Button(action: { store.activeColor = hex }) {
                    Circle()
                        .fill(Color(hexString: hex))
                        .frame(width: 26, height: 26)
                        .overlay(
                            Circle()
                                .strokeBorder(store.activeColor == hex ? Color.accentColor : Color.white.opacity(0.15), lineWidth: 2)
                                .padding(-2)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.2), radius: 6, y: 3)
    }

    private var selectedElement: WhiteboardElement? {
        if let id = store.selectedElementId {
            return store.state.elements.first(where: { $0.id == id })
        }
        return nil
    }

    @ViewBuilder
    private var contextBar: some View {
        if editingTextId != nil {
            HStack(spacing: 10) {
                TextField("Label", text: $editingTextValue)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Capsule())
                    .focused($isTextFieldFocused)
                    .onSubmit { commitTextEdit() }
                    .onAppear { isTextFieldFocused = true }

                Button(action: { commitTextEdit() }) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)
            }
            .contextPill
        } else {
            VStack(spacing: 6) {
                contextColorRow
                contextActionRow
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.2), radius: 6, y: 3)
        }
    }

    private var contextColorRow: some View {
        HStack(spacing: 8) {
            ForEach(Self.paletteColors, id: \.self) { hex in
                let currentColor = selectedElement?.fill ?? selectedElement?.stroke
                Button(action: {
                    if let id = store.selectedElementId, let el = selectedElement {
                        if el.type == .path || el.type == .text {
                            store.recolor(id: id, fill: nil, stroke: hex)
                        } else {
                            store.recolor(id: id, fill: hex, stroke: nil)
                        }
                    }
                }) {
                    Circle()
                        .fill(Color(hexString: hex))
                        .frame(width: 22, height: 22)
                        .overlay(
                            Circle()
                                .strokeBorder(currentColor == hex ? Color.accentColor : Color.white.opacity(0.15), lineWidth: 2)
                                .padding(-2)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var contextActionRow: some View {
        HStack(spacing: 4) {
            contextAction(icon: "square.3.layers.3d.down.backward", disabled: !canMoveBackward) {
                if let id = store.selectedElementId { store.moveBackward(id: id) }
            }
            contextAction(icon: "square.3.layers.3d.top.filled", disabled: !canMoveForward) {
                if let id = store.selectedElementId { store.moveForward(id: id) }
            }

            if selectedElement?.type == .rect || selectedElement?.type == .ellipse {
                Divider().frame(height: 18).opacity(0.3)
                contextAction(icon: selectedElement?.type == .rect ? "circle" : "rectangle") {
                    if let id = store.selectedElementId { store.changeShape(id: id) }
                }
            }

            Divider().frame(height: 18).opacity(0.3)

            contextAction(icon: "pencil") {
                if let id = store.selectedElementId {
                    editingTextValue = selectedElement?.label ?? ""
                    editingTextId = id
                }
            }

            contextAction(icon: "plus.square.on.square") {
                if let id = store.selectedElementId { store.duplicate(id: id) }
            }

            Divider().frame(height: 18).opacity(0.3)

            contextAction(icon: "trash", tint: .red.opacity(0.8)) {
                if let id = store.selectedElementId { store.removeElement(id: id) }
            }
        }
    }

    private var canMoveForward: Bool {
        if let id = store.selectedElementId { return store.canMoveForward(id: id) }
        return false
    }

    private var canMoveBackward: Bool {
        if let id = store.selectedElementId { return store.canMoveBackward(id: id) }
        return false
    }

    private func contextAction(icon: String, tint: Color = .primary.opacity(0.8), disabled: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .frame(width: 34, height: 30)
                .foregroundColor(disabled ? .secondary.opacity(0.3) : tint)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }

}

private extension View {
    var contextPill: some View {
        self
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.2), radius: 6, y: 3)
    }
}

extension WhiteboardSheet {
    func commitTextEdit() {
        isTextFieldFocused = false
        if let id = editingTextId {
            if editingTextValue.isEmpty {
                store.removeElement(id: id)
            } else {
                store.updateLabel(id: id, label: editingTextValue)
            }
        }
        editingTextId = nil
        editingTextValue = ""
    }
}

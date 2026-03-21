// WhiteboardSheet+ContextBar.swift

import SwiftUI

extension WhiteboardSheet {
    var selectedElement: WhiteboardElement? {
        if let id = store.selectedElementId {
            return store.state.elements.first(where: { $0.id == id })
        }
        return nil
    }

    @ViewBuilder
    var contextBar: some View {
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

    var contextColorRow: some View {
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

    var contextActionRow: some View {
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

    var canMoveForward: Bool {
        if let id = store.selectedElementId { return store.canMoveForward(id: id) }
        return false
    }

    var canMoveBackward: Bool {
        if let id = store.selectedElementId { return store.canMoveBackward(id: id) }
        return false
    }

    func contextAction(icon: String, tint: Color = .primary.opacity(0.8), disabled: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .frame(width: 34, height: 30)
                .foregroundColor(disabled ? .secondary.opacity(0.3) : tint)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }

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

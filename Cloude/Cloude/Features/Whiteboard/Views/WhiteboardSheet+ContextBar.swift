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
            HStack(spacing: DS.Spacing.m) {
                TextField("Label", text: $editingTextValue)
                    .textFieldStyle(.plain)
                    .font(.system(size: DS.Text.m, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, DS.Spacing.m)
                    .padding(.vertical, DS.Spacing.s)
                    .background(Color.white.opacity(DS.Opacity.s))
                    .clipShape(Capsule())
                    .focused($isTextFieldFocused)
                    .onSubmit { commitTextEdit() }
                    .onAppear { isTextFieldFocused = true }

                Button(action: { commitTextEdit() }) {
                    Image(systemName: "checkmark")
                        .font(.system(size: DS.Icon.s, weight: .semibold))
                        .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)
            }
            .contextPill
        } else {
            VStack(spacing: DS.Spacing.s) {
                contextColorRow
                contextActionRow
            }
        }
    }

    var contextColorRow: some View {
        HStack(spacing: DS.Spacing.s) {
            ForEach(Self.paletteColors, id: \.self) { hex in
                let currentColor = selectedElement?.fill ?? selectedElement?.stroke
                Button(action: {
                    if store.selectedIds.count > 1 {
                        store.recolorMany(ids: store.selectedIds, hex: hex)
                    } else if let id = store.selectedElementId, let el = selectedElement {
                        if el.type == .path || el.type == .text {
                            store.recolor(id: id, fill: nil, stroke: hex)
                        } else {
                            store.recolor(id: id, fill: hex, stroke: nil)
                        }
                    }
                }) {
                    Circle()
                        .fill(Color(hexString: hex))
                        .frame(width: DS.Size.m, height: DS.Size.m)
                        .overlay(
                            Circle()
                                .strokeBorder(currentColor == hex ? Color.accentColor : Color.white.opacity(DS.Opacity.s), lineWidth: DS.Stroke.l)
                                .padding(-DS.Spacing.xs)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    var contextActionRow: some View {
        HStack(spacing: DS.Spacing.xs) {
            if store.activeTool == .multiSelect {
                multiSelectActionRow
            } else {
                singleSelectActionRow
            }
        }
    }

    @ViewBuilder
    var singleSelectActionRow: some View {
        contextAction(icon: "square.3.layers.3d.down.backward", disabled: !canMoveBackward) {
            if let id = store.selectedElementId { store.moveBackward(id: id) }
        }
        contextAction(icon: "square.3.layers.3d.top.filled", disabled: !canMoveForward) {
            if let id = store.selectedElementId { store.moveForward(id: id) }
        }

        if selectedElement?.type == .rect || selectedElement?.type == .ellipse || selectedElement?.type == .triangle {
            Divider().frame(height: DS.Icon.m).opacity(DS.Opacity.m)
            let nextIcon: String = {
                switch selectedElement?.type {
                case .rect: return "circle"
                case .ellipse: return "triangle"
                case .triangle: return "rectangle"
                default: return "circle"
                }
            }()
            contextAction(icon: nextIcon) {
                if let id = store.selectedElementId { store.changeShape(id: id) }
            }
        }

        if selectedElement?.type == .text {
            Divider().frame(height: DS.Icon.m).opacity(DS.Opacity.m)
            fontSizeButtons
        }

        Divider().frame(height: DS.Icon.m).opacity(DS.Opacity.m)

        contextAction(icon: "pencil") {
            if let id = store.selectedElementId {
                editingTextValue = selectedElement?.label ?? ""
                editingTextId = id
            }
        }

        contextAction(icon: "plus.square.on.square") {
            if let id = store.selectedElementId { store.duplicate(id: id) }
        }

        Divider().frame(height: DS.Icon.m).opacity(DS.Opacity.m)

        contextAction(icon: "trash", tint: .red.opacity(DS.Opacity.l)) {
            if let id = store.selectedElementId {
                store.removeElement(id: id)
            }
        }
    }

    @ViewBuilder
    var multiSelectActionRow: some View {
        Text("\(store.selectedIds.count)")
            .font(.system(size: DS.Text.m, weight: .bold, design: .monospaced))
            .foregroundColor(.accentColor)
            .frame(width: DS.Size.m)

        Divider().frame(height: DS.Icon.m).opacity(DS.Opacity.m)

        contextAction(icon: "square.3.layers.3d.down.backward") {
            store.moveBackwardMany(ids: store.selectedIds)
        }
        contextAction(icon: "square.3.layers.3d.top.filled") {
            store.moveForwardMany(ids: store.selectedIds)
        }

        Divider().frame(height: DS.Icon.m).opacity(DS.Opacity.m)

        contextAction(icon: "square.2.layers.3d", disabled: store.selectedIds.count < 2) {
            store.groupSelected()
        }

        if store.hasGroup(in: store.selectedIds) {
            contextAction(icon: "square.2.layers.3d.bottom.filled") {
                store.ungroupSelected()
            }
        }

        Divider().frame(height: DS.Icon.m).opacity(DS.Opacity.m)

        contextAction(icon: "trash", tint: .red.opacity(DS.Opacity.l), disabled: store.selectedIds.isEmpty) {
            store.removeElements(ids: Array(store.selectedIds))
            store.clearSelection()
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

    func contextAction(icon: String, tint: Color = .primary.opacity(DS.Opacity.l), disabled: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: DS.Icon.s))
                .frame(width: DS.Size.l, height: DS.Size.m)
                .foregroundColor(disabled ? .secondary.opacity(DS.Opacity.m) : tint)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }

    var fontSizeButtons: some View {
        HStack(spacing: DS.Spacing.xs) {
            contextAction(icon: "textformat.size.smaller") {
                if let id = store.selectedElementId {
                    let current = selectedElement?.fontSize ?? 14
                    store.updateElement(id: id, fontSize: max(8, current - 2))
                }
            }
            contextAction(icon: "textformat.size.larger") {
                if let id = store.selectedElementId {
                    let current = selectedElement?.fontSize ?? 14
                    store.updateElement(id: id, fontSize: min(48, current + 2))
                }
            }
        }
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

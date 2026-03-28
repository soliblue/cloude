// WhiteboardSheet+Toolbar.swift

import SwiftUI

extension WhiteboardSheet {
    @ToolbarContentBuilder
    var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            HStack(spacing: DS.Spacing.m) {
                Button(action: { store.undo() }) {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: DS.Icon.s, weight: .medium))
                        .foregroundColor(store.canUndo ? .primary : .secondary.opacity(DS.Opacity.m))
                }
                .agenticID("whiteboard_undo_button")
                .disabled(!store.canUndo)

                Button(action: { store.redo() }) {
                    Image(systemName: "arrow.uturn.forward")
                        .font(.system(size: DS.Icon.s, weight: .medium))
                        .foregroundColor(store.canRedo ? .primary : .secondary.opacity(DS.Opacity.m))
                }
                .agenticID("whiteboard_redo_button")
                .disabled(!store.canRedo)
            }
        }

        ToolbarItem(placement: .topBarTrailing) {
            HStack(spacing: DS.Spacing.m) {
                if onSendSnapshot != nil {
                    Button(action: {
                        onSendSnapshot?()
                    }) {
                        Image(systemName: "paperplane")
                            .font(.system(size: DS.Icon.s, weight: .medium))
                            .foregroundColor(isConnected ? .primary : .secondary.opacity(DS.Opacity.m))
                    }
                    .agenticID("whiteboard_send_snapshot_button")
                    .disabled(!isConnected)

                    Divider().frame(height: DS.Icon.m)
                }

                Button(action: { exportAsImage() }) {
                    Image(systemName: "square.and.arrow.down")
                        .font(.system(size: DS.Icon.s, weight: .medium))
                        .foregroundColor(.primary)
                }
                .agenticID("whiteboard_export_button")

                Divider().frame(height: DS.Icon.m)

                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: DS.Icon.s, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .agenticID("whiteboard_close_button")
            }
            .padding(.horizontal, DS.Spacing.l)
        }
    }

    @ViewBuilder
    var floatingToolbar: some View {
        VStack(spacing: DS.Spacing.s) {
            if store.activeTool == .multiSelect || (!store.selectedIds.isEmpty && store.activeTool == .hand) {
                contextBar
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            if store.activeTool != .hand && store.activeTool != .multiSelect {
                colorBar
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            toolBar
        }
        .animation(.quickTransition, value: store.activeTool)
        .animation(.quickTransition, value: !store.selectedIds.isEmpty)
        .animation(.quickTransition, value: store.selectedElementIds.count)
    }

    private var toolBar: some View {
        HStack(spacing: 0) {
            toolButton(icon: "hand.draw", tool: .hand)
            toolButton(icon: "checklist.unchecked", tool: .multiSelect)
            toolButton(icon: "rectangle", tool: .rect)
            toolButton(icon: "circle", tool: .ellipse)
            toolButton(icon: "triangle", tool: .triangle)
            toolButton(icon: "textformat", tool: .text)
            toolButton(icon: "pencil.tip", tool: .pencil)
            toolButton(icon: "arrow.right", tool: .arrow)
        }
        .padding(.horizontal, DS.Spacing.s)
        .padding(.vertical, DS.Spacing.s)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
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
                store.selectedElementIds.removeAll()
            }
        }) {
            Image(systemName: icon)
                .font(.system(size: DS.Icon.m))
                .frame(width: DS.Size.l, height: DS.Size.l)
                .background(store.activeTool == tool ? Color.accentColor.opacity(DS.Opacity.m) : Color.clear)
                .cornerRadius(DS.Radius.m)
                .foregroundColor(store.activeTool == tool ? .accentColor : .primary.opacity(DS.Opacity.l))
        }
        .agenticID("whiteboard_tool_\(toolID(tool))")
        .buttonStyle(.plain)
    }

    private func toolID(_ tool: WhiteboardStore.ActiveTool) -> String {
        switch tool {
        case .hand: "hand"
        case .multiSelect: "multi_select"
        case .rect: "rect"
        case .ellipse: "ellipse"
        case .triangle: "triangle"
        case .text: "text"
        case .pencil: "pencil"
        case .arrow: "arrow"
        }
    }

    static let paletteColors = ["#FFFFFF", "#FF6B6B", "#4ECDC4", "#FFE66D", "#A78BFA", "#FF8C42"]

    private var colorBar: some View {
        HStack(spacing: DS.Spacing.m) {
            ForEach(Self.paletteColors, id: \.self) { hex in
                Button(action: { store.activeColor = hex }) {
                    Circle()
                        .fill(Color(hexString: hex))
                        .frame(width: DS.Size.m, height: DS.Size.m)
                        .overlay(
                            Circle()
                                .strokeBorder(store.activeColor == hex ? Color.accentColor : Color.white.opacity(DS.Opacity.s), lineWidth: DS.Stroke.l)
                                .padding(-DS.Spacing.xs)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, DS.Spacing.l)
        .padding(.vertical, DS.Spacing.s)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
    }
}

extension View {
    var contextPill: some View {
        self
            .padding(.horizontal, DS.Spacing.l)
            .padding(.vertical, DS.Spacing.s)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
        }
}

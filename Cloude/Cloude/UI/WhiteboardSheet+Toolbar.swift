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
            HStack(spacing: 12) {
                if onSendSnapshot != nil {
                    Button(action: {
                        onSendSnapshot?()
                    }) {
                        Image(systemName: "paperplane")
                            .fontWeight(.medium)
                            .foregroundColor(isConnected ? .primary : .secondary.opacity(0.3))
                    }
                    .disabled(!isConnected)

                    Divider().frame(height: 20)
                }

                Button(action: { exportAsImage() }) {
                    Image(systemName: "square.and.arrow.down")
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                }

                Divider().frame(height: 20)

                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    @ViewBuilder
    var floatingToolbar: some View {
        VStack(spacing: 8) {
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
                store.selectedElementIds.removeAll()
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
}

extension View {
    var contextPill: some View {
        self
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.2), radius: 6, y: 3)
    }
}

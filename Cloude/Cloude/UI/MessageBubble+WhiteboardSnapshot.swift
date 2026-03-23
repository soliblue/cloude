// MessageBubble+WhiteboardSnapshot.swift

import SwiftUI

struct WhiteboardSnapshotPill: View {
    let text: String
    @State private var showDetail = false

    private var snapshot: WhiteboardState? {
        let jsonPart = text.replacingOccurrences(of: "[whiteboard snapshot]\n", with: "")
        if let data = jsonPart.data(using: .utf8) {
            return try? JSONDecoder().decode(WhiteboardState.self, from: data)
        }
        return nil
    }

    var body: some View {
        if let state = snapshot {
            HStack(spacing: 4) {
                Image(systemName: "rectangle.on.rectangle.angled")
                    .font(.system(size: 9))
                    .foregroundColor(.accentColor)
                Text("snapshot")
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundColor(.accentColor)
                Text("\(state.elements.count) elements")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 8))
            .highPriorityGesture(TapGesture().onEnded { showDetail = true })
            .sheet(isPresented: $showDetail) {
                WhiteboardSnapshotSheet(state: state)
            }
        } else {
            Text(text)
        }
    }
}

struct WhiteboardSnapshotSheet: View {
    let state: WhiteboardState
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Canvas") {
                    LabeledContent("Viewport", value: String(format: "(%.0f, %.0f) @ %.1fx", state.viewport.x, state.viewport.y, state.viewport.zoom))
                    LabeledContent("Elements", value: "\(state.elements.count)")
                }

                Section("Elements") {
                    ForEach(state.elements) { el in
                        WhiteboardElementRow(element: el)
                    }
                }
            }
            .navigationTitle("Whiteboard Snapshot")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
}

private struct WhiteboardElementRow: View {
    let element: WhiteboardElement

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: elementIcon(element.type))
                .font(.system(size: 11))
                .foregroundColor(.accentColor)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(element.type.rawValue)
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    Text(element.id)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.secondary)
                }

                HStack(spacing: 8) {
                    if element.type != .arrow {
                        Text(String(format: "(%.0f, %.0f)", element.x, element.y))
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    if element.type == .rect || element.type == .ellipse {
                        Text(String(format: "%.0f×%.0f", element.w, element.h))
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    if let label = element.label, !label.isEmpty {
                        Text("\"\(label)\"")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    if let from = element.from, let to = element.to {
                        Text("\(from) → \(to)")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    if let points = element.points {
                        Text("\(points.count) pts")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()

            if let fill = element.fill {
                Circle()
                    .fill(Color(hexString: fill))
                    .frame(width: 12, height: 12)
            }
            if let stroke = element.stroke {
                Circle()
                    .strokeBorder(Color(hexString: stroke), lineWidth: 2)
                    .frame(width: 12, height: 12)
            }
        }
    }

    private func elementIcon(_ type: WhiteboardElementType) -> String {
        switch type {
        case .rect: return "rectangle"
        case .ellipse: return "circle"
        case .triangle: return "triangle"
        case .text: return "textformat"
        case .path: return "pencil.tip"
        case .arrow: return "arrow.right"
        }
    }
}

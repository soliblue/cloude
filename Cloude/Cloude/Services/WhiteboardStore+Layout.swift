// WhiteboardStore+Layout.swift

import Foundation

extension WhiteboardStore {
    func applyLayout(_ type: String, to elements: inout [WhiteboardElement], origin: (Double, Double), spacing: Double) {
        switch type {
        case "row":
            var x = origin.0
            for i in elements.indices {
                elements[i].x = x
                elements[i].y = origin.1
                x += elements[i].w + spacing
            }
        case "column":
            var y = origin.1
            for i in elements.indices {
                elements[i].x = origin.0
                elements[i].y = y
                y += elements[i].h + spacing
            }
        case "grid":
            let cols = max(1, Int(ceil(sqrt(Double(elements.count)))))
            for i in elements.indices {
                let col = i % cols
                let row = i / cols
                elements[i].x = origin.0 + Double(col) * (elements[i].w + spacing)
                elements[i].y = origin.1 + Double(row) * (elements[i].h + spacing)
            }
        case "tree":
            layoutTree(&elements, origin: origin, spacing: spacing)
        case "radial":
            let cx = origin.0 + 200
            let cy = origin.1 + 200
            let radius = max(120, Double(elements.count) * 30)
            for i in elements.indices {
                let angle = (2 * .pi / Double(elements.count)) * Double(i) - .pi / 2
                elements[i].x = cx + radius * cos(angle) - elements[i].w / 2
                elements[i].y = cy + radius * sin(angle) - elements[i].h / 2
            }
        default:
            break
        }
    }

    func resolveRelativePositions(_ elements: inout [WhiteboardElement]) {
        let existing = Dictionary(state.elements.map { ($0.id, $0) }, uniquingKeysWith: { _, last in last })
        var batch = Dictionary(elements.map { ($0.id, $0) }, uniquingKeysWith: { _, last in last })

        for i in elements.indices {
            if let rel = elements[i].relativeTo {
                let target = existing[rel.id] ?? batch[rel.id]
                if let target {
                    let gap = rel.gap ?? 20
                    switch rel.position {
                    case "right":
                        elements[i].x = target.x + target.w + gap
                        elements[i].y = target.y + (target.h - elements[i].h) / 2
                    case "left":
                        elements[i].x = target.x - elements[i].w - gap
                        elements[i].y = target.y + (target.h - elements[i].h) / 2
                    case "below":
                        elements[i].x = target.x + (target.w - elements[i].w) / 2
                        elements[i].y = target.y + target.h + gap
                    case "above":
                        elements[i].x = target.x + (target.w - elements[i].w) / 2
                        elements[i].y = target.y - elements[i].h - gap
                    default:
                        break
                    }
                    batch[elements[i].id] = elements[i]
                }
                elements[i].relativeTo = nil
            }
        }
    }

    private func layoutTree(_ elements: inout [WhiteboardElement], origin: (Double, Double), spacing: Double) {
        if elements.isEmpty { return }
        let arrowElements = elements.filter { $0.type == .arrow }
        let nodeElements = elements.filter { $0.type != .arrow }
        if nodeElements.isEmpty { return }

        var children: [String: [String]] = [:]
        var hasParent: Set<String> = []
        for arrow in arrowElements {
            if let from = arrow.from, let to = arrow.to {
                children[from, default: []].append(to)
                hasParent.insert(to)
            }
        }
        let roots = nodeElements.filter { !hasParent.contains($0.id) }
        let rootIds = roots.isEmpty ? [nodeElements[0].id] : roots.map(\.id)

        var positions: [String: (Double, Double)] = [:]
        var currentX = origin.0

        func layoutSubtree(_ nodeId: String, depth: Int) {
            let kids = children[nodeId] ?? []
            if kids.isEmpty {
                positions[nodeId] = (currentX, origin.1 + Double(depth) * (80 + spacing))
                currentX += 140 + spacing
            } else {
                for kid in kids { layoutSubtree(kid, depth: depth + 1) }
                let childXs = kids.compactMap { positions[$0]?.0 }
                let midX = (childXs.min()! + childXs.max()!) / 2
                positions[nodeId] = (midX, origin.1 + Double(depth) * (80 + spacing))
            }
        }

        for rootId in rootIds { layoutSubtree(rootId, depth: 0) }

        for i in elements.indices {
            if let pos = positions[elements[i].id] {
                elements[i].x = pos.0
                elements[i].y = pos.1
            }
        }
    }
}

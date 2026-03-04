import SwiftUI

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = layout(in: proposal.width ?? 0, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(in: bounds.width, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            let remainingWidth = bounds.width - position.x
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: ProposedViewSize(width: remainingWidth, height: nil)
            )
        }
    }

    private func layout(in width: CGFloat, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxWidth: CGFloat = 0

        for subview in subviews {
            let idealSize = subview.sizeThatFits(.unspecified)
            let fitsInRow = x + idealSize.width <= width || x == 0
            if !fitsInRow {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            let remainingWidth = width - x
            let constrainedSize = idealSize.width > remainingWidth
                ? subview.sizeThatFits(ProposedViewSize(width: remainingWidth, height: nil))
                : idealSize
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, constrainedSize.height)
            x += constrainedSize.width + spacing
            maxWidth = max(maxWidth, x - spacing)
        }

        return (CGSize(width: maxWidth, height: y + rowHeight), positions)
    }
}

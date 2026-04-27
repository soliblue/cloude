import SwiftUI

struct ChatTypewriterTextRenderer: TextRenderer, Animatable {
    var revealedGlyphs: Double

    var animatableData: Double {
        get { revealedGlyphs }
        set { revealedGlyphs = newValue }
    }

    func draw(layout: Text.Layout, in context: inout GraphicsContext) {
        let fadeWindow: Double = 6
        let slide: CGFloat = 4
        var index = 0
        for line in layout {
            for run in line {
                for slice in run {
                    let raw = (revealedGlyphs - Double(index)) / fadeWindow
                    let progress = min(1, max(0, raw))
                    let eased = progress * progress * (3 - 2 * progress)
                    var copy = context
                    copy.opacity = eased
                    copy.translateBy(x: (1 - eased) * -slide, y: 0)
                    copy.draw(slice)
                    index += 1
                }
            }
        }
    }
}

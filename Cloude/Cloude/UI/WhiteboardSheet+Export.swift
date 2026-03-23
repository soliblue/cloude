// WhiteboardSheet+Export.swift

import SwiftUI

extension WhiteboardSheet {
    @MainActor
    func exportAsImage() {
        if let uiImage = Self.renderToImage(store: store) {
            UIImageWriteToSavedPhotosAlbum(uiImage, nil, nil, nil)
            showExportSuccess = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                showExportSuccess = false
            }
        }
    }

    @MainActor
    static func renderToImage(store: WhiteboardStore) -> UIImage? {
        let sheet = WhiteboardSheet(store: store)
        let size = CGSize(width: 1000, height: 1000)
        let canvas = Canvas { context, canvasSize in
            context.fill(Path(CGRect(origin: .zero, size: canvasSize)), with: .color(Color.themeBackground))

            let viewport = store.state.viewport
            let s = canvasSize.width / 1000.0 * viewport.zoom

            context.translateBy(x: canvasSize.width / 2, y: canvasSize.height / 2)
            context.scaleBy(x: s, y: s)
            context.translateBy(x: viewport.x - 500, y: viewport.y - 500)

            let sorted = store.state.elements.sorted { ($0.z ?? 0) < ($1.z ?? 0) }
            let elementDict = Dictionary(sorted.map { ($0.id, $0) }, uniquingKeysWith: { _, last in last })
            for element in sorted {
                sheet.drawElement(element, context: context, elementDict: elementDict)
            }
        }
        .frame(width: size.width, height: size.height)

        let renderer = ImageRenderer(content: canvas)
        renderer.scale = 2.0
        return renderer.uiImage
    }
}

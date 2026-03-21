// WhiteboardElement.swift

import Foundation

enum WhiteboardElementType: String, Codable {
    case rect
    case ellipse
    case text
    case path
    case arrow
}

struct WhiteboardElement: Codable, Identifiable {
    let id: String
    var type: WhiteboardElementType
    var x: Double
    var y: Double
    var w: Double
    var h: Double
    var label: String?
    var fill: String?
    var stroke: String?
    var points: [[Double]]?
    var closed: Bool?
    var from: String?
    var to: String?

    init(id: String = UUID().uuidString.prefix(8).lowercased().description,
         type: WhiteboardElementType,
         x: Double = 0, y: Double = 0,
         w: Double = 100, h: Double = 60,
         label: String? = nil,
         fill: String? = nil,
         stroke: String? = nil,
         points: [[Double]]? = nil,
         closed: Bool? = nil,
         from: String? = nil,
         to: String? = nil) {
        self.id = id
        self.type = type
        self.x = x
        self.y = y
        self.w = w
        self.h = h
        self.label = label
        self.fill = fill
        self.stroke = stroke
        self.points = points
        self.closed = closed
        self.from = from
        self.to = to
    }
}

struct WhiteboardViewport: Codable {
    var x: Double = 0
    var y: Double = 0
    var zoom: Double = 1.0
}

struct WhiteboardState: Codable {
    var viewport: WhiteboardViewport = WhiteboardViewport()
    var elements: [WhiteboardElement] = []
}

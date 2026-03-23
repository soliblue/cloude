// WhiteboardElement.swift

import Foundation

enum WhiteboardElementType: String, Codable {
    case rect
    case ellipse
    case text
    case triangle
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
    var z: Int?
    var fontSize: Double?
    var strokeWidth: Double?
    var strokeStyle: String?
    var opacity: Double?
    var groupId: String?
    var relativeTo: RelativePosition?

    struct RelativePosition: Codable {
        let id: String
        let position: String
        let gap: Double?
    }

    enum CodingKeys: String, CodingKey {
        case id, type, x, y, w, h, label, fill, stroke, points, closed, from, to
        case z, fontSize, strokeWidth, strokeStyle, opacity, groupId, relativeTo
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString.prefix(8).lowercased()
        type = try c.decode(WhiteboardElementType.self, forKey: .type)
        x = try c.decodeIfPresent(Double.self, forKey: .x) ?? 0
        y = try c.decodeIfPresent(Double.self, forKey: .y) ?? 0
        w = try c.decodeIfPresent(Double.self, forKey: .w) ?? 100
        h = try c.decodeIfPresent(Double.self, forKey: .h) ?? 60
        label = try c.decodeIfPresent(String.self, forKey: .label)
        fill = try c.decodeIfPresent(String.self, forKey: .fill)
        stroke = try c.decodeIfPresent(String.self, forKey: .stroke)
        points = try c.decodeIfPresent([[Double]].self, forKey: .points)
        closed = try c.decodeIfPresent(Bool.self, forKey: .closed)
        from = try c.decodeIfPresent(String.self, forKey: .from)
        to = try c.decodeIfPresent(String.self, forKey: .to)
        z = try c.decodeIfPresent(Int.self, forKey: .z)
        fontSize = try c.decodeIfPresent(Double.self, forKey: .fontSize)
        strokeWidth = try c.decodeIfPresent(Double.self, forKey: .strokeWidth)
        strokeStyle = try c.decodeIfPresent(String.self, forKey: .strokeStyle)
        opacity = try c.decodeIfPresent(Double.self, forKey: .opacity)
        groupId = try c.decodeIfPresent(String.self, forKey: .groupId)
        relativeTo = try c.decodeIfPresent(RelativePosition.self, forKey: .relativeTo)
    }

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
         to: String? = nil,
         z: Int? = nil,
         fontSize: Double? = nil,
         strokeWidth: Double? = nil,
         strokeStyle: String? = nil,
         opacity: Double? = nil,
         groupId: String? = nil) {
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
        self.z = z
        self.fontSize = fontSize
        self.strokeWidth = strokeWidth
        self.strokeStyle = strokeStyle
        self.opacity = opacity
        self.groupId = groupId
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

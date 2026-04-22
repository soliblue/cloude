import Foundation

enum SessionRandom {
    static let names: [String] = [
        "Spark", "Nova", "Pulse", "Echo", "Drift", "Blaze", "Frost", "Dusk",
        "Dawn", "Flux", "Glow", "Haze", "Mist", "Peak", "Reef", "Sage",
        "Tide", "Vale", "Wave", "Zen", "Bolt", "Cove", "Edge", "Fern",
        "Grid", "Hive", "Jade", "Kite", "Leaf", "Maze", "Nest", "Opal",
        "Pine", "Quill", "Rush", "Sand", "Twig", "Vine", "Wisp", "Yarn",
        "Arc", "Bay", "Cliff", "Dell", "Elm", "Fog", "Glen", "Hill",
        "Ivy", "Jet", "Key", "Lane", "Moon", "Nook", "Oak", "Path",
    ]

    static let symbols: [String] = [
        "star", "heart", "bolt", "flame", "leaf", "moon", "sun.max", "cloud",
        "sparkles", "wand.and.stars", "lightbulb", "paperplane", "rocket",
        "globe", "map", "flag", "bookmark", "tag", "bubble.left", "terminal",
        "paintbrush", "pencil", "folder", "doc", "book", "briefcase",
        "hammer", "wrench", "gearshape", "cpu", "lock", "key", "eye",
        "hare", "tortoise", "bird", "fish", "tree", "mountain.2", "drop",
    ]

    static func name() -> String { names.randomElement() ?? "Chat" }
    static func symbol() -> String { symbols.randomElement() ?? "sparkles" }
}

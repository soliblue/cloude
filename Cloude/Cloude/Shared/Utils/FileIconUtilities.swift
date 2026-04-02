import SwiftUI
import CloudeShared

private let fileExtensionIcons: [String: String] = [
    "swift": "swift",
    "m": "c.square",
    "h": "h.square",
    "c": "c.square",
    "cpp": "c.square",
    "hpp": "c.square",
    "py": "chevron.left.forwardslash.chevron.right",
    "rb": "diamond",
    "go": "chevron.left.forwardslash.chevron.right",
    "rs": "gearshape.2",
    "java": "cup.and.saucer",
    "kt": "k.square",
    "js": "j.square",
    "ts": "t.square",
    "jsx": "j.square",
    "tsx": "t.square",
    "vue": "v.square",
    "svelte": "s.square",
    "html": "chevron.left.forwardslash.chevron.right",
    "css": "paintbrush",
    "scss": "paintbrush",
    "sass": "paintbrush",
    "less": "paintbrush",
    "json": "curlybraces",
    "xml": "chevron.left.forwardslash.chevron.right",
    "plist": "list.bullet.rectangle",
    "yaml": "text.alignleft",
    "yml": "text.alignleft",
    "toml": "text.alignleft",
    "md": "doc.richtext",
    "txt": "doc.text",
    "rtf": "doc.richtext",
    "sh": "terminal",
    "bash": "terminal",
    "zsh": "terminal",
    "fish": "terminal",
    "png": "photo",
    "jpg": "photo",
    "jpeg": "photo",
    "gif": "photo.stack",
    "webp": "photo",
    "heic": "photo",
    "svg": "scribble.variable",
    "pdf": "doc.text.fill",
    "mp4": "film",
    "mov": "film",
    "avi": "film",
    "mkv": "film",
    "webm": "film",
    "mp3": "waveform",
    "wav": "waveform",
    "aac": "waveform",
    "flac": "waveform",
    "ogg": "waveform",
    "m4a": "waveform",
    "zip": "archivebox",
    "tar": "archivebox",
    "gz": "archivebox",
    "rar": "archivebox",
    "7z": "archivebox",
    "xcode": "hammer",
    "xcodeproj": "hammer",
    "xcworkspace": "hammer",
    "xcconfig": "hammer",
    "lock": "lock",
    "env": "key",
    "gitignore": "eye.slash",
    "dockerignore": "eye.slash",
    "dockerfile": "shippingbox",
    "makefile": "hammer"
]

func fileIconName(for filename: String) -> String {
    let ext = filename.pathExtension.lowercased()
    let basename = filename.deletingPathExtension.lowercased()

    if basename == "dockerfile" { return "shippingbox" }
    if basename == "makefile" { return "hammer" }
    if basename.hasSuffix(".d") { return "doc.text" }

    return fileExtensionIcons[ext] ?? "doc"
}

func fileIconColor(for filename: String) -> Color {
    let ext = filename.pathExtension.lowercased()
    switch ext {
    case "swift", "xcodeproj", "xcworkspace": return .orange
    case "py": return .yellow
    case "js", "jsx": return .yellow
    case "ts", "tsx": return .blue
    case "go": return .cyan
    case "rs": return Color(red: 0.87, green: 0.46, blue: 0.19)
    case "rb": return .red
    case "java", "kt": return .orange
    case "html", "xml", "plist": return .orange
    case "css", "scss", "sass", "less": return .blue
    case "json": return .yellow
    case "yaml", "yml", "toml": return .pink
    case "md", "txt", "rtf": return .secondary
    case "sh", "bash", "zsh", "fish": return .green
    case "png", "jpg", "jpeg", "gif", "webp", "heic", "svg": return .purple
    case "pdf": return .red
    case "mp4", "mov", "avi", "mkv", "webm": return .indigo
    case "mp3", "wav", "aac", "flac", "ogg", "m4a": return .pink
    case "zip", "tar", "gz", "rar", "7z": return .brown
    case "env": return .yellow
    case "lock": return .gray
    default: return .secondary
    }
}

import Foundation

#if os(iOS)
extension FileEntry {
    public var icon: String {
        if isDirectory {
            return "folder.fill"
        }

        guard let mime = mimeType else { return "doc.fill" }

        if mime.hasPrefix("image/") {
            return "photo.fill"
        } else if mime.hasPrefix("video/") {
            return "video.fill"
        } else if mime.hasPrefix("audio/") {
            return "music.note"
        } else if mime.hasPrefix("text/") || mime.contains("json") || mime.contains("javascript") {
            return "doc.text.fill"
        } else if mime.contains("pdf") {
            return "doc.richtext.fill"
        } else if mime.contains("zip") || mime.contains("tar") || mime.contains("gzip") {
            return "doc.zipper"
        }

        return "doc.fill"
    }

    public var isMedia: Bool {
        guard let mime = mimeType else { return false }
        return mime.hasPrefix("image/") || mime.hasPrefix("video/") || mime.hasPrefix("audio/")
    }

    public var isImage: Bool {
        mimeType?.hasPrefix("image/") ?? false
    }

    public var isVideo: Bool {
        mimeType?.hasPrefix("video/") ?? false
    }

    public var isAudio: Bool {
        mimeType?.hasPrefix("audio/") ?? false
    }

    public var isPDF: Bool {
        mimeType?.contains("pdf") ?? false
    }

    public var isText: Bool {
        guard let mime = mimeType else { return false }
        return mime.hasPrefix("text/") || mime.contains("json") || mime.contains("javascript") || mime.contains("xml")
    }

    public var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
}
#endif

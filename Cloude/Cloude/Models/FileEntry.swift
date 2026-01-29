//
//  FileEntry.swift
//  Cloude
//
//  File entry model for directory listings
//

import Foundation

struct FileEntry: Codable, Identifiable {
    var id: String { path }
    let name: String
    let path: String
    let isDirectory: Bool
    let size: Int64
    let modified: Date
    let mimeType: String?

    var icon: String {
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

    var isMedia: Bool {
        guard let mime = mimeType else { return false }
        return mime.hasPrefix("image/") || mime.hasPrefix("video/") || mime.hasPrefix("audio/")
    }

    var isImage: Bool {
        mimeType?.hasPrefix("image/") ?? false
    }

    var isVideo: Bool {
        mimeType?.hasPrefix("video/") ?? false
    }

    var isText: Bool {
        guard let mime = mimeType else { return false }
        return mime.hasPrefix("text/") || mime.contains("json") || mime.contains("javascript") || mime.contains("xml")
    }

    var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
}

// ToolCallLabel+Truncation.swift

import Foundation
import CloudeShared

extension ToolCallLabel {
    func truncateText(_ text: String, maxLength: Int) -> String {
        text.count > maxLength ? String(text.prefix(maxLength - 1)) + "…" : text
    }

    func truncatePath(_ path: String, maxLength: Int) -> String {
        guard path.count > maxLength else { return path }
        let components = path.split(separator: "/")
        guard components.count > 1, let last = components.last else {
            return String(path.suffix(maxLength - 1)) + "…"
        }
        if last.count >= maxLength - 3 {
            return "…/\(last.suffix(maxLength - 3))"
        }
        return "…/\(last)"
    }

    func truncateURL(_ url: String, maxLength: Int) -> String {
        var clean = url
        if clean.hasPrefix("https://") { clean = String(clean.dropFirst(8)) }
        else if clean.hasPrefix("http://") { clean = String(clean.dropFirst(7)) }
        if clean.hasPrefix("www.") { clean = String(clean.dropFirst(4)) }
        return clean.count > maxLength ? String(clean.prefix(maxLength - 1)) + "…" : clean
    }

    func truncateFilename(_ filename: String, maxLength: Int) -> String {
        guard filename.count > maxLength else { return filename }
        let ext = filename.pathExtension
        let name = filename.deletingPathExtension
        let availableLength = maxLength - ext.count - (ext.isEmpty ? 0 : 4)
        guard availableLength > 0 else { return filename }
        return "\(name.prefix(availableLength))….\(ext)"
    }

    func midTruncate(_ text: String, maxLength: Int) -> String {
        guard text.count > maxLength else { return text }
        let half = (maxLength - 1) / 2
        let start = text.prefix(half)
        let end = text.suffix(half)
        return "\(start)…\(end)"
    }
}

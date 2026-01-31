import Foundation

#if os(macOS)
import UniformTypeIdentifiers

extension FileEntry {
    public static func from(url: URL) -> FileEntry? {
        let fileManager = FileManager.default
        guard let attrs = try? fileManager.attributesOfItem(atPath: url.path) else {
            return nil
        }

        let isDirectory = (attrs[.type] as? FileAttributeType) == .typeDirectory
        let size = (attrs[.size] as? Int64) ?? 0
        let modified = (attrs[.modificationDate] as? Date) ?? Date()

        var mimeType: String? = nil
        if !isDirectory {
            if let type = UTType(filenameExtension: url.pathExtension) {
                mimeType = type.preferredMIMEType
            }
        }

        return FileEntry(
            name: url.lastPathComponent,
            path: url.path,
            isDirectory: isDirectory,
            size: size,
            modified: modified,
            mimeType: mimeType
        )
    }
}
#endif

import Foundation
import UniformTypeIdentifiers
import CloudeShared

class FileService {
    static let shared = FileService()

    private let fileManager = FileManager.default
    private let maxFileSize: Int64 = 50 * 1024 * 1024 // 50MB max

    func listDirectory(at path: String) -> Result<[FileEntry], Error> {
        let url = URL(fileURLWithPath: path)

        do {
            let contents = try fileManager.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey],
                options: [.skipsHiddenFiles]
            )

            let entries = contents.compactMap { FileEntry.from(url: $0) }
                .sorted { (a, b) in
                    // Directories first, then alphabetically
                    if a.isDirectory != b.isDirectory {
                        return a.isDirectory
                    }
                    return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
                }

            return .success(entries)
        } catch {
            return .failure(error)
        }
    }

    func getFile(at path: String) -> Result<(data: Data, mimeType: String, size: Int64), Error> {
        let url = URL(fileURLWithPath: path)

        do {
            let attrs = try fileManager.attributesOfItem(atPath: path)
            let size = (attrs[.size] as? Int64) ?? 0

            guard size <= maxFileSize else {
                return .failure(FileError.fileTooLarge(size: size, max: maxFileSize))
            }

            let data = try Data(contentsOf: url)

            var mimeType = "application/octet-stream"
            if let type = UTType(filenameExtension: url.pathExtension) {
                mimeType = type.preferredMIMEType ?? mimeType
            }

            return .success((data: data, mimeType: mimeType, size: size))
        } catch {
            return .failure(error)
        }
    }

    enum FileError: LocalizedError {
        case fileTooLarge(size: Int64, max: Int64)

        var errorDescription: String? {
            switch self {
            case .fileTooLarge(let size, let max):
                let formatter = ByteCountFormatter()
                formatter.countStyle = .file
                return "File too large (\(formatter.string(fromByteCount: size))). Max: \(formatter.string(fromByteCount: max))"
            }
        }
    }
}

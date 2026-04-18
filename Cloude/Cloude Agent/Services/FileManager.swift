import Foundation
import UniformTypeIdentifiers
import CloudeShared

class FileService {
    static let shared = FileService()

    private let fileManager = FileManager.default
    private let chunkSize: Int = 512 * 1024
    private let maxFileSize: Int64 = 100 * 1024 * 1024

    func listDirectory(at path: String) -> Result<[FileEntry], Error> {
        let url = URL(fileURLWithPath: path)

        do {
            let contents = try fileManager.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey],
                options: []
            )

            let entries = contents.compactMap { FileEntry.from(url: $0) }
                .sorted { (a, b) in
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

    struct FileResult {
        let data: Data
        let mimeType: String
        let size: Int64
        let needsChunking: Bool
    }

    func getFile(at path: String) -> Result<FileResult, Error> {
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

            let needsChunking = data.count > chunkSize
            return .success(FileResult(data: data, mimeType: mimeType, size: size, needsChunking: needsChunking))
        } catch {
            return .failure(error)
        }
    }

    func chunkData(_ data: Data) -> [Data] {
        var chunks: [Data] = []
        var offset = 0
        while offset < data.count {
            let end = min(offset + chunkSize, data.count)
            chunks.append(data.subdata(in: offset..<end))
            offset = end
        }
        return chunks
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

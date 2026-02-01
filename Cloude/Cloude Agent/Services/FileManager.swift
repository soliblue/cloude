import Foundation
import UniformTypeIdentifiers
import CloudeShared

class FileService {
    static let shared = FileService()

    private let fileManager = FileManager.default
    private let chunkSize: Int = 512 * 1024 // 512KB chunks (~700KB after base64, safe for iOS WebSocket)
    private let maxFileSize: Int64 = 100 * 1024 * 1024 // 100MB absolute max

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

    private let imageExtensions = Set(["jpg", "jpeg", "png", "heic", "heif", "tiff", "tif", "gif", "bmp"])
    private let thumbnailMaxSize = 200 * 1024 // 200KB thumbnail target

    func isImage(at path: String) -> Bool {
        let ext = (path as NSString).pathExtension.lowercased()
        return imageExtensions.contains(ext)
    }

    func needsThumbnail(at path: String) -> Bool {
        guard isImage(at: path) else { return false }
        guard let attrs = try? fileManager.attributesOfItem(atPath: path),
              let size = attrs[.size] as? Int64 else { return false }
        return size > Int64(chunkSize)
    }

    func generateThumbnail(for path: String) -> Data? {
        let tempDir = FileManager.default.temporaryDirectory
        let thumbPath = tempDir.appendingPathComponent("thumb_\(UUID().uuidString).jpg").path

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sips")
        process.arguments = [
            "-Z", "800",
            "-s", "format", "jpeg",
            "-s", "formatOptions", "low",
            path,
            "--out", thumbPath
        ]

        do {
            try process.run()
            process.waitUntilExit()

            if process.terminationStatus == 0 {
                let data = try Data(contentsOf: URL(fileURLWithPath: thumbPath))
                try? FileManager.default.removeItem(atPath: thumbPath)
                return data
            }
        } catch {
            Log.error("[Thumbnail] Failed: \(error)")
        }

        try? FileManager.default.removeItem(atPath: thumbPath)
        return nil
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

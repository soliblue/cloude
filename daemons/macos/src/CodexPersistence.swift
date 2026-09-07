import Darwin
import Foundation

enum CodexPersistence {
    static func write(
        _ data: Data, to url: URL, exclusive: Bool = false, synchronize: (Int32) -> Bool = { Darwin.fsync($0) == 0 }
    ) -> Bool {
        var directories = [url.deletingLastPathComponent()]
        while !FileManager.default.fileExists(atPath: directories.last!.path) {
            directories.append(directories.last!.deletingLastPathComponent())
        }
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700])
        if (try? data.write(to: url, options: exclusive ? .withoutOverwriting : .atomic)) != nil,
            (try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)) != nil
        {
            let descriptor = Darwin.open(url.path, O_RDONLY)
            if descriptor >= 0 {
                let synced = synchronize(descriptor)
                Darwin.close(descriptor)
                if synced {
                    for path in directories {
                        let directory = Darwin.open(path.path, O_RDONLY)
                        if directory < 0 { return false }
                        let syncedDirectory = synchronize(directory)
                        Darwin.close(directory)
                        if !syncedDirectory { return false }
                    }
                    return true
                }
            }
        }
        return false
    }
}

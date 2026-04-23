import Foundation

final class FolderAccessProbeService {
    static let shared = FolderAccessProbeService()
    static let grantedKey = "folderAccessGranted"

    private let userDirectories: [FileManager.SearchPathDirectory] = [
        .desktopDirectory,
        .documentDirectory,
        .downloadsDirectory,
        .moviesDirectory,
        .musicDirectory,
        .picturesDirectory,
    ]

    private init() {}

    func request(completion: ((Bool) -> Void)? = nil) {
        DispatchQueue.global(qos: .utility).async {
            var isGranted = true
            var visited = Set<String>()
            for url in self.userDirectoryURLs + self.mountedVolumeURLs {
                let path = url.standardizedFileURL.path
                if visited.insert(path).inserted, !self.canRead(url) {
                    isGranted = false
                }
            }
            DispatchQueue.main.async {
                UserDefaults.standard.set(isGranted, forKey: Self.grantedKey)
                completion?(isGranted)
            }
        }
    }

    private func canRead(_ url: URL) -> Bool {
        (try? FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )) != nil
    }

    private var userDirectoryURLs: [URL] {
        userDirectories.flatMap {
            FileManager.default.urls(for: $0, in: .userDomainMask)
        }
    }

    private var mountedVolumeURLs: [URL] {
        FileManager.default.mountedVolumeURLs(
            includingResourceValuesForKeys: nil,
            options: [.skipHiddenVolumes]
        ) ?? []
    }
}

import Foundation

enum ChatTranscriptionAudio {
    @concurrent static func write(_ audio: Data) async -> URL? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".wav")
        #if os(iOS)
        let written =
            (try? audio.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])) != nil
        #else
        let written = (try? audio.write(to: url, options: .atomic)) != nil
        #endif
        if written {
            try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
            return url
        }
        return nil
    }

    @concurrent static func remove(_ url: URL) async { try? FileManager.default.removeItem(at: url) }
}

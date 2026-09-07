import Foundation
import UIKit

@main struct DraftBackgroundTests {
    @MainActor static func main() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let disk = ChatDraftDisk(root: root)
        ChatDraftService.disk = disk
        let id = UUID()
        ChatDraftService.flushForBackground()
        precondition(UIApplication.shared.acquired.isEmpty, "No lease for clean drafts")
        ChatDraftService.setText("Keep unsent after expiration", for: id)
        ChatDraftService.flushForBackground()
        ChatDraftService.flushForBackground()
        precondition(UIApplication.shared.acquired.count == 1, "Repeated callbacks share one lease")
        let expireFirst = UIApplication.shared.expirations[0]
        expireFirst()
        for _ in 0..<10000 where UIApplication.shared.ended.isEmpty { await Task.yield() }
        precondition(UIApplication.shared.ended.count == 1)
        precondition(ChatDraftStore.text(for: id) == "Keep unsent after expiration")
        ChatDraftService.setText("Retry survives", for: id)
        ChatDraftService.flushForBackground()
        precondition(UIApplication.shared.acquired.count == 2)
        expireFirst()
        await ChatDraftService.flush()
        for _ in 0..<10000 where UIApplication.shared.ended.count < 2 { await Task.yield() }
        precondition(UIApplication.shared.ended.count == 2, "Expired older generation cannot end newer token")
        precondition(UIApplication.shared.ended[0] != UIApplication.shared.ended[1], "Each lease ended once")
        let saved = try await disk.read(id)
        precondition(saved?.text == "Retry survives")
        expireFirst()
        await Task.yield()
        precondition(UIApplication.shared.ended.count == 2, "Late expiration after completion does not double-end")
        UIApplication.shared.rejectNext = true
        ChatDraftService.setText("No granted lease", for: id)
        ChatDraftService.flushForBackground()
        await ChatDraftService.flush()
        for _ in 0..<100 { await Task.yield() }
        precondition(!UIApplication.shared.ended.contains(.invalid))
        let denied = try await disk.read(id)
        precondition(denied?.text == "No granted lease")
        print(
            "PASS draft UIKit lifecycle: coalesced callbacks, expiration release, generation fencing, retry preservation, exactly-once release and invalid lease handling"
        )
    }
}

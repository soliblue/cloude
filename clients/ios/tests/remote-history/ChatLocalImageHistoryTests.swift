import CoreGraphics
import Foundation
import ImageIO
import SwiftData
import UniformTypeIdentifiers

struct ChatLocalImageHistoryTests {
    @MainActor static func run(context: ModelContext) async throws {
        let endpoint = Endpoint()
        context.insert(endpoint)
        let session = Session(endpoint: endpoint)
        session.path = "/project"
        context.insert(session)
        let pathA = "/tmp/outside project/写真 \"one\" #?.png"
        let pathB = "/tmp/second.png"
        let png = image()
        check(await ChatHistoryImage.validRaster(png))
        HTTPClient.imageCalls = []
        let history: [String: Any] = [
            "turns": [
                [
                    "status": "completed",
                    "items": [
                        [
                            "id": "mixed-photos", "type": "userMessage",
                            "content": [
                                ["type": "localImage", "path": pathA, "detail": NSNull()],
                                ["type": "image", "url": "data:image/png;base64," + png.base64EncodedString()],
                                ["type": "localImage", "path": pathB],
                                ["type": "image", "url": "https://example.invalid/do-not-fetch"],
                                ["type": "localImage", "path": "file:///tmp/no.png"],
                                ["type": "localImage", "path": "relative.png"],
                                ["type": "localImage", "path": "//network/share.png"],
                                ["type": "localImage", "path": "/tmp/bad\npath.png"],
                            ],
                        ]
                    ],
                ]
            ]
        ]
        check(await ChatActions.importHistory(history, session: session, context: context))
        let sessionId = session.id
        let message = try context.fetch(
            FetchDescriptor<ChatMessage>(predicate: #Predicate { $0.sessionId == sessionId })
        ).first!
        check(HTTPClient.imageCalls.isEmpty, "History import must not fetch remote images eagerly")
        check(
            message.imageSources?.count == 8 && message.imageSources?[0] == pathA && message.imageSources?[2] == pathB)
        check(Array(message.imagesData.prefix(3)) == [Data(), png, Data()] && message.text.isEmpty)
        HTTPClient.imageResponse = response(png)
        check(
            await ChatHistoryImageService.load(source: pathB, message: message, session: session, context: context))
        check(Array(message.imagesData.prefix(3)) == [Data(), png, png])
        HTTPClient.imageResponse = response(Data(), status: 404)
        check(
            !(await ChatHistoryImageService.load(source: pathA, message: message, session: session, context: context)))
        check(Array(message.imagesData.prefix(3)) == [Data(), png, png])
        check(await ChatActions.importHistory(history, session: session, context: context))
        check(
            Array(message.imagesData.prefix(3)) == [Data(), png, png],
            "Refresh must preserve successful partial attachments")
        HTTPClient.imageResponse = response(png, status: 206, range: "bytes 0-\(png.count - 1)/\(png.count)")
        check(
            await ChatHistoryImageService.load(source: pathA, message: message, session: session, context: context))
        check(Array(message.imagesData.prefix(3)) == [png, png, png])
        check(HTTPClient.imageCalls.last?.query == ["path": pathA])
        check(HTTPClient.imageCalls.last?.path == "/sessions/\(session.id.uuidString)/files/read")
        check(HTTPClient.imageCalls.last?.maximumBytes == 20_971_520 - 2 * png.count)
        let calls = HTTPClient.imageCalls.count
        await FileCache.shared.remove(endpoint: endpoint.cacheId)
        HTTPClient.imageResponse = nil
        check(
            await ChatHistoryImageService.load(source: pathA, message: message, session: session, context: context))
        check(await ChatActions.importHistory(history, session: session, context: context))
        check(HTTPClient.imageCalls.count == calls && Array(message.imagesData.prefix(3)) == [png, png, png])
        let childId = UUID()
        ChatActions.copyHistory(from: session.id, to: childId, context: context)
        let child = try context.fetch(FetchDescriptor<ChatMessage>(predicate: #Predicate { $0.sessionId == childId }))
            .first!
        check(child.imageSources == message.imageSources && child.imagesData == message.imagesData)
        print(
            "PASS lazy local-image import, source order, mixed partial retry, exact outside-project paths, offline bytes and fork preservation"
        )
        for scenario in [
            "cached", "range", "truncated", "non-image", "revision", "deleted", "source-changed", "canceled",
        ] {
            let path = "/tmp/\(UUID().uuidString).png"
            let photo = ChatMessage(sessionId: session.id, role: .user, images: [Data()])
            photo.imageSources = [path]
            context.insert(photo)
            HTTPClient.beforeImage = nil
            HTTPClient.imageResponse = response(png)
            if scenario == "cached" {
                await FileCache.shared.store(png, endpoint: endpoint.cacheId, path: path, category: "files")
                HTTPClient.imageResponse = nil
            }
            if scenario == "range" {
                HTTPClient.imageResponse = response(png, status: 206, range: "bytes 0-\(png.count - 1)/9999")
            }
            if scenario == "truncated" { HTTPClient.imageResponse = response(Data(png.prefix(20))) }
            if scenario == "non-image" { HTTPClient.imageResponse = response(Data("not an image".utf8)) }
            let oldCache = endpoint.cacheId
            if scenario == "revision" { HTTPClient.beforeImage = { endpoint.connectionRevision = UUID() } }
            if scenario == "deleted" { HTTPClient.beforeImage = { context.delete(photo) } }
            if scenario == "source-changed" { HTTPClient.beforeImage = { photo.imageSources = ["/tmp/other.png"] } }
            let result: Bool
            if scenario == "canceled" {
                var release: CheckedContinuation<Void, Never>?
                HTTPClient.beforeImage = { await withCheckedContinuation { release = $0 } }
                let task = Task { @MainActor in
                    await ChatHistoryImageService.load(source: path, message: photo, session: session, context: context)
                }
                while release == nil { await Task.yield() }
                task.cancel()
                release?.resume()
                result = await task.value
            } else {
                result = await ChatHistoryImageService.load(
                    source: path, message: photo, session: session, context: context)
            }
            check(result == (scenario == "cached"), scenario)
            if scenario != "deleted" {
                check(photo.imagesData == (scenario == "cached" ? [png] : [Data()]), scenario)
            }
            if scenario != "cached" {
                check(await FileCache.shared.cached(endpoint: oldCache, path: path) == nil, scenario)
            }
            await FileCache.shared.remove(endpoint: oldCache)
        }
        HTTPClient.beforeImage = nil
        await FileCache.shared.remove(endpoint: endpoint.cacheId)
        print(
            "PASS cached remote image recovery, incomplete/non-image rejection, connection/deletion/source/cancellation fences and no stale cache writes"
        )
    }

    static func check(_ condition: Bool, _ message: String = "") {
        precondition(condition, message)
    }

    static func image() -> Data {
        let context = CGContext(
            data: nil, width: 3, height: 2, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.setFillColor(CGColor(red: 0.1, green: 0.7, blue: 0.4, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 3, height: 2))
        let data = NSMutableData()
        let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(destination, context.makeImage()!, nil)
        check(CGImageDestinationFinalize(destination))
        return data as Data
    }

    static func response(_ data: Data, status: Int = 200, range: String? = nil) -> (Data, HTTPURLResponse) {
        (
            data,
            HTTPURLResponse(
                url: URL(string: "http://fixture")!, statusCode: status, httpVersion: nil,
                headerFields: range.map { ["Content-Range": $0] })!
        )
    }
}

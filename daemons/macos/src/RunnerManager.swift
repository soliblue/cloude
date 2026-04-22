import Foundation
import Network

final class RunnerManager {
    static let shared = RunnerManager()

    private let queue = DispatchQueue(label: "soli.Cloude.runner")
    private var runners: [String: Runner] = [:]

    func start(
        sessionId: String, path: String, prompt: String, images: [[String: String]],
        existsOnServer: Bool, model: String?, effort: String?, connection: NWConnection
    ) {
        queue.async {
            NSLog("[RunnerManager] start sessionId=\(sessionId) path=\(path) existsOnServer=\(existsOnServer) model=\(model ?? "nil") effort=\(effort ?? "nil") promptChars=\(prompt.count) images=\(images.count)")
            if let existing = self.runners[sessionId] {
                NSLog("[RunnerManager] aborting existing runner sessionId=\(sessionId)")
                existing.abort()
            }
            let runner = Runner(
                sessionId: sessionId, hasStartedBefore: existsOnServer, model: model, effort: effort, queue: self.queue)
            runner.onFinish = { [weak self, weak runner] in
                self?.queue.async {
                    if let runner, self?.runners[sessionId] === runner {
                        self?.runners.removeValue(forKey: sessionId)
                    }
                }
            }
            self.runners[sessionId] = runner
            runner.subscribe(connection)
            let resolvedPrompt = ImageDropbox.prepare(cwd: path, prompt: prompt, images: images)
            runner.spawn(path: path, prompt: resolvedPrompt)
        }
    }

    func hasRunner(sessionId: String) -> Bool {
        queue.sync { runners[sessionId] != nil }
    }

    func resume(sessionId: String, afterSeq: Int, connection: NWConnection) {
        queue.async {
            if let runner = self.runners[sessionId] {
                runner.subscribe(connection, afterSeq: afterSeq)
            } else {
                connection.cancel()
            }
        }
    }

    func abort(sessionId: String) -> Bool {
        queue.sync {
            if let runner = self.runners[sessionId] {
                runner.abort()
                return true
            }
            return false
        }
    }
}

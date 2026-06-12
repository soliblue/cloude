import Foundation
import Network

final class RunnerManager {
    static let shared = RunnerManager()

    private let queue = DispatchQueue(label: "soli.Cloude.runner")
    private var runners: [String: Runner] = [:]

    func start(
        sessionId: String, path: String, prompt: String, images: [[String: String]],
        existsOnServer: Bool, model: String?, effort: String?, permissionMode: String?,
        connection: NWConnection
    ) {
        queue.async {
            NSLog(
                "[RunnerManager] start sessionId=\(sessionId) path=\(path) existsOnServer=\(existsOnServer) model=\(model ?? "nil") effort=\(effort ?? "nil") permissionMode=\(permissionMode ?? "nil") promptChars=\(prompt.count) images=\(images.count)"
            )
            let previous = self.runners[sessionId]
            let runner = Runner(
                sessionId: sessionId, hasStartedBefore: existsOnServer, model: model, effort: effort,
                permissionMode: permissionMode, queue: self.queue)
            runner.onFinish = { [weak self, weak runner] in
                self?.queue.async {
                    if let runner, self?.runners[sessionId] === runner {
                        self?.runners.removeValue(forKey: sessionId)
                    }
                }
            }
            self.runners[sessionId] = runner
            runner.subscribe(connection)
            let resolvedPrompt = ImageDropbox.prepare(cwd: path, prompt: prompt, images: images, sessionId: sessionId)
            let begin = { runner.spawn(path: path, prompt: resolvedPrompt) }
            if let previous, !previous.hasExited {
                NSLog("[RunnerManager] aborting existing runner sessionId=\(sessionId)")
                let previousFinish = previous.onFinish
                previous.onFinish = {
                    previousFinish?()
                    begin()
                }
                previous.abort()
            } else {
                begin()
            }
        }
    }

    func resumeIfExists(sessionId: String, afterSeq: Int, connection: NWConnection) -> Bool {
        queue.sync {
            if let runner = runners[sessionId] {
                runner.subscribe(connection, afterSeq: afterSeq)
                return true
            }
            return false
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

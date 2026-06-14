import Foundation
import Network

final class RunnerManager {
    static let shared = RunnerManager()

    private let queue = DispatchQueue(label: "soli.Cloude.runner")
    private var runners: [String: ChatRunning] = [:]

    func start(
        sessionId: String, path: String, prompt: String, images: [[String: String]],
        existsOnServer: Bool, provider: String?, model: String?, effort: String?, permissionMode: String?,
        connection: NWConnection
    ) {
        queue.async {
            NSLog(
                "[RunnerManager] start sessionId=\(sessionId) path=\(path) existsOnServer=\(existsOnServer) provider=\(provider ?? "nil") model=\(model ?? "nil") effort=\(effort ?? "nil") permissionMode=\(permissionMode ?? "nil") promptChars=\(prompt.count) images=\(images.count)"
            )
            let previous = self.runners[sessionId]
            let useCodex = provider == "codex" || model?.hasPrefix("gpt-") == true
            let runner: ChatRunning
            if useCodex {
                runner = CodexRunner(
                    sessionId: sessionId, hasStartedBefore: existsOnServer, model: model,
                    effort: effort, permissionMode: permissionMode, queue: self.queue)
            } else {
                runner = Runner(
                    sessionId: sessionId, hasStartedBefore: existsOnServer, model: model,
                    effort: effort, permissionMode: permissionMode, queue: self.queue)
            }
            let runnerIdentity = ObjectIdentifier(runner as AnyObject)
            runner.onFinish = { [weak self] in
                self?.queue.async {
                    if let current = self?.runners[sessionId],
                        ObjectIdentifier(current as AnyObject) == runnerIdentity
                    {
                        self?.runners.removeValue(forKey: sessionId)
                    }
                }
            }
            self.runners[sessionId] = runner
            runner.subscribe(connection, afterSeq: -1)
            let imagePaths = ImageDropbox.materialize(images: images, sessionId: sessionId)
            let begin = {
                if let codex = runner as? CodexRunner {
                    codex.spawn(path: path, prompt: prompt, imagePaths: imagePaths)
                } else if let claude = runner as? Runner {
                    claude.spawn(
                        path: path,
                        prompt: ImageDropbox.promptWithImagePaths(prompt: prompt, imagePaths: imagePaths))
                }
            }
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

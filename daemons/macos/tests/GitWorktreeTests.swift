import Darwin
import Foundation

@main
struct GitWorktreeTests {
    static func main() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(
            "afto-native-worktrees-\(UUID().uuidString)")
        let repository = root.appendingPathComponent("source")
        try FileManager.default.createDirectory(at: repository, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        setenv("CLOUDE_DATA", root.appendingPathComponent("data").path, 1)
        func git(_ arguments: [String]) -> String {
            let (output, code) = GitProcess.run(arguments, cwd: repository)
            precondition(code == 0, arguments.joined(separator: " "))
            return output.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        _ = git(["init", "-q"])
        _ = git(["config", "user.email", "fixture@example.invalid"])
        _ = git(["config", "user.name", "Afto Fixture"])
        _ = git(["config", "commit.gpgsign", "false"])
        try Data("committed\n".utf8).write(to: repository.appendingPathComponent("file.txt"))
        _ = git(["add", "file.txt"])
        _ = git(["commit", "-qm", "Initial"])
        let head = git(["rev-parse", "HEAD"])
        _ = git(["branch", "base"])
        try Data("staged\n".utf8).write(to: repository.appendingPathComponent("file.txt"))
        _ = git(["add", "file.txt"])
        try Data("unstaged\n".utf8).write(to: repository.appendingPathComponent("file.txt"))
        try Data("untracked\n".utf8).write(to: repository.appendingPathComponent("extra.txt"))
        let index = try Data(contentsOf: repository.appendingPathComponent(".git/index"))
        let id = UUID().uuidString
        let created = GitWorktreeService.create(
            path: repository.path, branch: "codex/test", baseRef: "base", requestId: id)
        precondition(created.0 == 200, String(describing: created))
        precondition(created.1["head"] as? String == head)
        let destination = URL(fileURLWithPath: created.1["path"] as! String)
        precondition(try! Data(contentsOf: destination.appendingPathComponent("file.txt")) == Data("committed\n".utf8))
        precondition(try! Data(contentsOf: repository.appendingPathComponent(".git/index")) == index)
        precondition(try! Data(contentsOf: repository.appendingPathComponent("file.txt")) == Data("unstaged\n".utf8))
        precondition(!FileManager.default.fileExists(atPath: destination.appendingPathComponent("extra.txt").path))
        _ = git(["branch", "-D", "base"])
        let retried = GitWorktreeService.create(
            path: repository.path, branch: "codex/test", baseRef: "base", requestId: id.lowercased())
        precondition(retried.0 == 200 && retried.1["path"] as? String == destination.path)
        precondition(
            GitWorktreeService.create(path: repository.path, branch: "other", baseRef: "base", requestId: id).0 == 409)
        precondition(
            GitWorktreeService.create(path: repository.path, branch: "codex/test", requestId: UUID().uuidString).0
                == 409)
        precondition(
            GitWorktreeService.create(path: repository.path, branch: "../bad", requestId: UUID().uuidString).0 == 400)
        precondition(GitWorktreeService.create(path: repository.path, branch: "valid", requestId: "invalid").0 == 400)
        precondition(
            GitWorktreeService.create(
                path: repository.path, branch: "valid", baseRef: "missing", requestId: UUID().uuidString
            ).0 == 400)
        let parallel = UUID().uuidString
        DispatchQueue.concurrentPerform(iterations: 4) { _ in
            let result = GitWorktreeService.create(
                path: repository.path, branch: "codex/concurrent", requestId: parallel)
            precondition(result.0 == 200 && result.1["head"] as? String == head)
        }
        precondition(GitWorktreeService.list(path: repository.path)?.count == 3)
        precondition(GitWorktreeService.branches(path: repository.path)?["branches"] as? [[String: Any]] != nil)
        let failed = UUID().uuidString.lowercased()
        let receipt = root.appendingPathComponent("data/worktrees/\(failed).json")
        try JSONEncoder().encode([
            "repository": repository.appendingPathComponent(".git").resolvingSymlinksInPath().path,
            "branch": "codex/recovered", "baseRef": "deleted-ref", "commit": head,
        ]).write(to: receipt)
        let recovered = GitWorktreeService.create(
            path: repository.path, branch: "codex/recovered", baseRef: "deleted-ref", requestId: failed)
        precondition(recovered.0 == 200 && recovered.1["head"] as? String == head)
        print(
            "Native worktrees: committed snapshot, dirty source preservation, retries after deleted base, request conflicts, concurrent creation and persisted commit recovery passed"
        )
    }
}

import Foundation

@main
struct GitHandlerTests {
    static func main() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("afto-native-git-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        func git(_ arguments: [String]) -> String {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
            process.arguments = ["-C", root.path] + arguments
            let output = Pipe()
            process.standardOutput = output
            process.standardError = FileHandle.nullDevice
            try! process.run()
            let data = output.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            precondition(process.terminationStatus == 0, arguments.joined(separator: " "))
            return String(decoding: data, as: UTF8.self)
        }
        func request(_ query: [String: String] = [:], body: [String: Any] = [:]) -> HTTPRequest {
            HTTPRequest(
                head: HTTPRequest.ParsedHead(
                    method: "GET", path: "/", query: ["path": root.path].merging(query) { _, next in next },
                    headers: [:], headerEnd: 0, contentLength: 0),
                body: try! JSONSerialization.data(withJSONObject: ["path": root.path].merging(body) { _, next in next })
            )
        }
        func json(_ response: HTTPResponse) -> [String: Any] {
            precondition(response.status == 200)
            if case .buffered(let data) = response.body {
                return try! JSONSerialization.jsonObject(with: data) as! [String: Any]
            }
            preconditionFailure("Expected a JSON response")
        }
        func mutate(_ action: String, files: [String] = [], message: String = "") -> HTTPResponse {
            GitHandler.mutate(request(body: ["action": action, "files": files, "message": message]), params: [:])
        }
        _ = git(["init", "-q"])
        _ = git(["config", "user.email", "fixture@example.invalid"])
        _ = git(["config", "user.name", "Afto Fixture"])
        _ = git(["config", "commit.gpgsign", "false"])
        _ = git(["config", "core.hooksPath", "/dev/null"])
        let files = [
            "[draft].txt", "d.txt", "café.swift", "a -> b.txt", "quote\".txt", "with\ttab.txt", "with\nnewline.txt",
        ]
        for file in files { try Data("before\n".utf8).write(to: root.appendingPathComponent(file)) }
        precondition(mutate("stage", files: ["[draft].txt"]).status == 200)
        precondition(git(["diff", "--cached", "--name-only", "-z"]) == "[draft].txt\0")
        precondition(mutate("unstage", files: ["[draft].txt"]).status == 200)
        precondition(FileManager.default.fileExists(atPath: root.appendingPathComponent("[draft].txt").path))
        let untracked = GitHandler.diff(request(["file": "[draft].txt"]), params: [:])
        if case .buffered(let data) = untracked.body {
            precondition(String(decoding: data, as: UTF8.self).contains("+before"))
        }
        precondition(mutate("stage", files: files).status == 200)
        precondition(mutate("commit", message: "Initial\tfiles").status == 200)
        for file in files { try Data("after\nextra\n".utf8).write(to: root.appendingPathComponent(file)) }
        let changes = json(GitHandler.status(request(), params: [:]))["changes"] as! [[String: Any]]
        precondition(Set(changes.compactMap { $0["path"] as? String }) == Set(files))
        precondition(changes.allSatisfy { $0["additions"] as? Int == 2 && $0["deletions"] as? Int == 1 })
        precondition(mutate("stage", files: ["[draft].txt"]).status == 200)
        precondition(mutate("commit", message: "Selected file only").status == 200)
        precondition(git(["show", "--format=", "--name-only", "-z", "HEAD"]) == "[draft].txt\0")
        let commits = json(GitHandler.log(request(["count": "2"]), params: [:]))["commits"] as! [[String: Any]]
        precondition(commits.count == 2 && (commits[0]["sha"] as? String)?.count == 40)
        precondition(commits[1]["subject"] as? String == "Initial\tfiles")
        let page =
            json(GitHandler.log(request(["skip": "1", "count": "1"]), params: [:]))["commits"] as! [[String: Any]]
        precondition(page.count == 1 && page[0]["sha"] as? String == commits[1]["sha"] as? String)
        precondition(GitHandler.commit(request(["sha": "--output=/tmp/no"]), params: [:]).status == 400)
        let detail = json(GitHandler.commit(request(["sha": commits[1]["sha"] as! String]), params: [:]))
        precondition(Set((detail["files"] as! [[String: Any]]).compactMap { $0["path"] as? String }) == Set(files))
        precondition(mutate("stage", files: ["../outside"]).status == 400)
        precondition(mutate("commit", message: "  ").status == 400)
        print(
            "Native Git handlers: literal staging, unborn unstage, Unicode filenames, statistics, staged-only commit, full SHA pagination and invalid arguments passed"
        )
    }
}

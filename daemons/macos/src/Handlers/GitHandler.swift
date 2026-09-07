import Foundation

enum GitHandler {
    private static let diffClampLines = 5000

    static func branches(_ request: HTTPRequest, params: [String: String]) -> HTTPResponse {
        if let path = request.query["path"], let value = GitWorktreeService.branches(path: path) {
            return HTTPResponse.json(200, value)
        }
        return HTTPResponse.json(400, ["error": "Choose a Git repository."])
    }

    static func worktrees(_ request: HTTPRequest, params: [String: String]) -> HTTPResponse {
        if let path = request.query["path"], let value = GitWorktreeService.list(path: path) {
            return HTTPResponse.json(200, ["worktrees": value])
        }
        return HTTPResponse.json(400, ["error": "Choose a Git repository."])
    }

    static func createWorktree(_ request: HTTPRequest, params: [String: String]) -> HTTPResponse {
        if let body = try? JSONSerialization.jsonObject(with: request.body) as? [String: Any],
            let path = body["path"] as? String, let branch = body["branch"] as? String
        {
            let (status, value) = GitWorktreeService.create(
                path: path, branch: branch, baseRef: body["baseRef"] as? String ?? "HEAD",
                requestId: body["requestId"] as? String ?? UUID().uuidString)
            return HTTPResponse.json(status, value)
        }
        return HTTPResponse.json(400, ["error": "Choose a repository and new branch name."])
    }

    static func mutate(_ request: HTTPRequest, params: [String: String]) -> HTTPResponse {
        if let body = try? JSONSerialization.jsonObject(with: request.body) as? [String: Any],
            let path = body["path"] as? String, let action = body["action"] as? String,
            ["stage", "unstage", "commit"].contains(action)
        {
            let cwd = URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
            let (inside, code) = GitProcess.run(["rev-parse", "--is-inside-work-tree"], cwd: cwd)
            if code == 0 && inside.trimmingCharacters(in: .whitespacesAndNewlines) == "true" {
                if action == "commit", let message = body["message"] as? String,
                    !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                {
                    let (output, result) = GitProcess.run(
                        ["commit", "-m", message.trimmingCharacters(in: .whitespacesAndNewlines)], cwd: cwd)
                    return result == 0
                        ? HTTPResponse.json(200, ["ok": true, "output": output])
                        : HTTPResponse.json(
                            409, ["error": "Commit failed. Check staged changes, Git identity, and hooks on your host."]
                        )
                }
                if ["stage", "unstage"].contains(action), let files = body["files"] as? [String],
                    !files.isEmpty, files.count <= 1000,
                    files.allSatisfy({
                        !$0.isEmpty && !$0.hasPrefix("/") && !$0.components(separatedBy: "/").contains("..")
                            && !$0.contains("\0")
                    })
                {
                    let headExists = GitProcess.run(["rev-parse", "--verify", "HEAD"], cwd: cwd).1 == 0
                    let arguments =
                        action == "stage" ? ["add"] : headExists ? ["restore", "--staged"] : ["rm", "--cached"]
                    let result = GitProcess.run(["--literal-pathspecs"] + arguments + ["--"] + files, cwd: cwd).1
                    return result == 0
                        ? HTTPResponse.json(200, ["ok": true])
                        : HTTPResponse.json(409, ["error": "Could not update the Git index. Refresh and try again."])
                }
            }
        }
        return HTTPResponse.json(400, ["error": "Invalid Git operation"])
    }

    static func status(_ request: HTTPRequest, params: [String: String]) -> HTTPResponse {
        if let path = request.query["path"] {
            let cwd = URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
            let (insideOutput, insideCode) = GitProcess.run(["rev-parse", "--is-inside-work-tree"], cwd: cwd)
            if insideCode != 0 || insideOutput.trimmingCharacters(in: .whitespacesAndNewlines) != "true" {
                return HTTPResponse.json(404, ["error": "not_a_repo"])
            }
            let branch = resolveBranch(cwd: cwd)
            let (ahead, behind) = resolveAheadBehind(cwd: cwd)
            let porcelainOut = GitProcess.run(["status", "--porcelain=v1", "-z", "-uall", "-M"], cwd: cwd).0
            let unstagedOut = GitProcess.run(["diff", "--numstat", "-z", "-M"], cwd: cwd).0
            let stagedOut = GitProcess.run(["diff", "--cached", "--numstat", "-z", "-M"], cwd: cwd).0
            var changes = parsePorcelain(porcelainOut)
            let unstagedStats = parseNumstat(unstagedOut)
            let stagedStats = parseNumstat(stagedOut)
            for index in changes.indices {
                let stats = (changes[index]["isStaged"] as? Bool ?? false) ? stagedStats : unstagedStats
                if let path = changes[index]["path"] as? String, let (add, del) = stats[path] {
                    changes[index]["additions"] = add
                    changes[index]["deletions"] = del
                }
            }
            return HTTPResponse.json(
                200,
                [
                    "branch": branch,
                    "ahead": ahead,
                    "behind": behind,
                    "changes": changes,
                ]
            )
        }
        return HTTPResponse.json(400, ["error": "missing_path"])
    }

    static func diff(_ request: HTTPRequest, params: [String: String]) -> HTTPResponse {
        if let path = request.query["path"], let file = request.query["file"] {
            let cwd = URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
            let staged = request.query["staged"] == "1" || request.query["staged"] == "true"
            let full = request.query["full"] == "1" || request.query["full"] == "true"
            var args = ["--literal-pathspecs", "diff", "--no-color", "--no-ext-diff", "--no-textconv"]
            if staged { args.append("--cached") }
            args.append("-M")
            args.append("--")
            args.append(file)
            var (output, code) = GitProcess.run(args, cwd: cwd)
            if code == 0 && output.isEmpty && !staged {
                let untracked = GitProcess.run(
                    ["--literal-pathspecs", "ls-files", "--others", "--exclude-standard", "-z", "--", file], cwd: cwd
                ).0
                if untracked.components(separatedBy: "\0").contains(file) {
                    (output, code) = GitProcess.run(
                        [
                            "diff", "--no-index", "--no-color", "--no-ext-diff", "--no-textconv", "--", "/dev/null",
                            file,
                        ], cwd: cwd)
                    if code == 1 { code = 0 }
                }
            }
            if code != 0 { return HTTPResponse.json(500, ["error": "diff_failed"]) }
            let lines = output.split(separator: "\n", omittingEmptySubsequences: false)
            if !full && lines.count > diffClampLines {
                let clamped = lines.prefix(diffClampLines).joined(separator: "\n")
                return HTTPResponse(
                    status: 200,
                    body: Data(clamped.utf8),
                    contentType: "text/plain; charset=utf-8",
                    extraHeaders: ["X-Diff-Truncated": String(lines.count)]
                )
            }
            return HTTPResponse.text(200, output)
        }
        return HTTPResponse.json(400, ["error": "missing_params"])
    }

    static func commit(_ request: HTTPRequest, params: [String: String]) -> HTTPResponse {
        if let path = request.query["path"], let sha = request.query["sha"],
            sha.range(of: "^[a-fA-F0-9]{4,40}$", options: .regularExpression) != nil
        {
            let cwd = URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
            let (meta, _) = GitProcess.run(["show", "-s", "--format=%H%n%an%n%aI%n%s%n%b", sha], cwd: cwd)
            let (numstat, _) = GitProcess.run(["show", "--numstat", "-z", "--format=", "-M", sha], cwd: cwd)
            let (diffText, code) = GitProcess.run(
                ["show", "--no-color", "--no-ext-diff", "--no-textconv", "--format=", "-M", sha], cwd: cwd)
            if code != 0 {
                return HTTPResponse.json(404, ["error": "not_found"])
            }
            let metaLines = meta.components(separatedBy: "\n")
            let files: [[String: Any]] = parseNumstat(numstat).map { path, counts in
                ["path": path, "additions": counts.0, "deletions": counts.1]
            }
            let body =
                metaLines.count > 4
                ? metaLines[4...].joined(separator: "\n").trimmingCharacters(
                    in: .whitespacesAndNewlines) : ""
            return HTTPResponse.json(
                200,
                [
                    "sha": metaLines.first ?? sha,
                    "author": metaLines.count > 1 ? metaLines[1] : "",
                    "date": metaLines.count > 2 ? metaLines[2] : "",
                    "subject": metaLines.count > 3 ? metaLines[3] : "",
                    "body": body,
                    "files": files,
                    "diff": diffText,
                ])
        }
        return HTTPResponse.json(400, ["error": "missing_params"])
    }

    static func log(_ request: HTTPRequest, params: [String: String]) -> HTTPResponse {
        if let path = request.query["path"] {
            let cwd = URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
            let count = min(200, max(1, Int(request.query["count"] ?? "") ?? 50))
            let skip = max(0, Int(request.query["skip"] ?? "") ?? 0)
            let format = "%H%x00%s%x00%an%x00%aI"
            let output = GitProcess.run(
                ["log", "-z", "--format=\(format)", "--skip=\(skip)", "--max-count=\(count)"],
                cwd: cwd
            ).0
            var commits: [[String: Any]] = []
            let fields = output.components(separatedBy: "\0")
            for index in stride(from: 0, to: fields.count, by: 4) where index + 3 < fields.count {
                if !fields[index].isEmpty {
                    commits.append([
                        "sha": fields[index], "subject": fields[index + 1], "author": fields[index + 2],
                        "date": fields[index + 3],
                    ])
                }
            }
            return HTTPResponse.json(200, ["commits": commits])
        }
        return HTTPResponse.json(400, ["error": "missing_path"])
    }

    private static func resolveBranch(cwd: URL) -> String {
        let (out, _) = GitProcess.run(["branch", "--show-current"], cwd: cwd)
        let trimmed = out.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        let (sha, _) = GitProcess.run(["rev-parse", "--short", "HEAD"], cwd: cwd)
        return sha.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func resolveAheadBehind(cwd: URL) -> (Int, Int) {
        let (upstream, code) = GitProcess.run(["rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{u}"], cwd: cwd)
        if code != 0 { return (0, 0) }
        let name = upstream.trimmingCharacters(in: .whitespacesAndNewlines)
        if name.isEmpty { return (0, 0) }
        let (out, rcode) = GitProcess.run(["rev-list", "--left-right", "--count", "\(name)...HEAD"], cwd: cwd)
        if rcode != 0 { return (0, 0) }
        let parts = out.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: "\t")
        if parts.count == 2, let behind = Int(parts[0]), let ahead = Int(parts[1]) {
            return (ahead, behind)
        }
        return (0, 0)
    }

    private static func parsePorcelain(_ output: String) -> [[String: Any]] {
        var results: [[String: Any]] = []
        let records = output.components(separatedBy: "\0")
        var index = 0
        while index < records.count {
            let line = records[index]
            index += 1
            if line.count >= 3 {
                let xy = Array(line.prefix(2))
                let path = String(line.dropFirst(3))
                if xy.contains("R") || xy.contains("C") { index += 1 }
                if xy[0] == "?" {
                    results.append(["path": path, "type": "untracked", "isStaged": false])
                } else {
                    if xy[0] != " " && xy[0] != "!" {
                        results.append(["path": path, "type": typeFor(xy[0]), "isStaged": true])
                    }
                    if xy[1] != " " && xy[1] != "!" {
                        results.append(["path": path, "type": typeFor(xy[1]), "isStaged": false])
                    }
                }
            }
        }
        return results
    }

    private static func typeFor(_ code: Character) -> String {
        switch code {
        case "A": return "added"
        case "M": return "modified"
        case "D": return "deleted"
        case "R": return "renamed"
        case "C": return "copied"
        case "U": return "conflicted"
        default: return "modified"
        }
    }

    private static func parseNumstat(_ output: String) -> [String: (Int, Int)] {
        var result: [String: (Int, Int)] = [:]
        let records = output.components(separatedBy: "\0")
        var index = 0
        while index < records.count {
            let parts = records[index].split(separator: "\t", maxSplits: 2, omittingEmptySubsequences: false)
            index += 1
            if parts.count == 3 {
                var path = String(parts[2])
                if path.isEmpty && index + 1 < records.count {
                    path = records[index + 1]
                    index += 2
                }
                result[path] = (Int(parts[0]) ?? 0, Int(parts[1]) ?? 0)
            }
        }
        return result
    }

}

import Foundation

enum GitHandler {
    private static let diffClampLines = 5000

    static func status(_ request: HTTPRequest, params: [String: String]) -> HTTPResponse {
        if let path = request.query["path"] {
            let cwd = URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
            let (insideOutput, insideCode) = runText(["rev-parse", "--is-inside-work-tree"], cwd: cwd)
            if insideCode != 0 || insideOutput.trimmingCharacters(in: .whitespacesAndNewlines) != "true" {
                return HTTPResponse.json(404, ["error": "not_a_repo"])
            }
            var branch = ""
            var ahead = 0
            var behind = 0
            var porcelainOut = ""
            var unstagedOut = ""
            var stagedOut = ""
            DispatchQueue.concurrentPerform(iterations: 5) { i in
                switch i {
                case 0: branch = resolveBranch(cwd: cwd)
                case 1: (ahead, behind) = resolveAheadBehind(cwd: cwd)
                case 2: porcelainOut = runText(["status", "--porcelain=v1", "-uall", "-M"], cwd: cwd).0
                case 3: unstagedOut = runText(["diff", "--numstat", "-M"], cwd: cwd).0
                default: stagedOut = runText(["diff", "--cached", "--numstat", "-M"], cwd: cwd).0
                }
            }
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
            var args = ["diff"]
            if staged { args.append("--cached") }
            args.append("-M")
            args.append("--")
            args.append(file)
            let output = runText(args, cwd: cwd).0
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

    static func log(_ request: HTTPRequest, params: [String: String]) -> HTTPResponse {
        if let path = request.query["path"] {
            let cwd = URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
            let count = Int(request.query["count"] ?? "") ?? 50
            let skip = Int(request.query["skip"] ?? "") ?? 0
            let format = "%h\t%s\t%an\t%aI"
            let output = runText(
                ["log", "--format=\(format)", "--skip=\(skip)", "--max-count=\(count)"],
                cwd: cwd
            ).0
            var commits: [[String: Any]] = []
            for line in output.split(separator: "\n") {
                let parts = line.split(separator: "\t", maxSplits: 3, omittingEmptySubsequences: false)
                if parts.count >= 4 {
                    var entry: [String: Any] = [:]
                    entry["sha"] = String(parts[0])
                    entry["subject"] = String(parts[1])
                    entry["author"] = String(parts[2])
                    entry["date"] = String(parts[3])
                    commits.append(entry)
                }
            }
            return HTTPResponse.json(200, ["commits": commits])
        }
        return HTTPResponse.json(400, ["error": "missing_path"])
    }

    private static func resolveBranch(cwd: URL) -> String {
        let (out, _) = runText(["branch", "--show-current"], cwd: cwd)
        let trimmed = out.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        let (sha, _) = runText(["rev-parse", "--short", "HEAD"], cwd: cwd)
        return sha.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func resolveAheadBehind(cwd: URL) -> (Int, Int) {
        let (upstream, code) = runText(["rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{u}"], cwd: cwd)
        if code != 0 { return (0, 0) }
        let name = upstream.trimmingCharacters(in: .whitespacesAndNewlines)
        if name.isEmpty { return (0, 0) }
        let (out, rcode) = runText(["rev-list", "--left-right", "--count", "\(name)...HEAD"], cwd: cwd)
        if rcode != 0 { return (0, 0) }
        let parts = out.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: "\t")
        if parts.count == 2, let behind = Int(parts[0]), let ahead = Int(parts[1]) {
            return (ahead, behind)
        }
        return (0, 0)
    }

    private static func parsePorcelain(_ output: String) -> [[String: Any]] {
        var results: [[String: Any]] = []
        for rawLine in output.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = String(rawLine)
            if line.count < 3 { continue }
            let xy = line.prefix(2)
            let x = xy[xy.startIndex]
            let y = xy[xy.index(after: xy.startIndex)]
            let rest = String(line.dropFirst(3))
            let path = extractPath(rest)
            if x == "?" {
                results.append(["path": path, "type": "untracked", "isStaged": false])
                continue
            }
            if x != " " && x != "!" {
                results.append(["path": path, "type": typeFor(x), "isStaged": true])
            }
            if y != " " && y != "!" {
                results.append(["path": path, "type": typeFor(y), "isStaged": false])
            }
        }
        return results
    }

    private static func extractPath(_ rest: String) -> String {
        if let arrow = rest.range(of: " -> ") {
            return String(rest[arrow.upperBound...])
        }
        return rest
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
        for rawLine in output.split(separator: "\n") {
            let parts = rawLine.split(separator: "\t", maxSplits: 2, omittingEmptySubsequences: false)
            if parts.count >= 3, let add = Int(parts[0]), let del = Int(parts[1]) {
                let pathField = String(parts[2])
                if let arrow = pathField.range(of: " => ") {
                    result[String(pathField[arrow.upperBound...])] = (add, del)
                } else {
                    result[pathField] = (add, del)
                }
            }
        }
        return result
    }

    private static func runText(_ args: [String], cwd: URL) -> (String, Int32) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = args
        process.currentDirectoryURL = cwd
        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr
        do {
            try process.run()
            process.waitUntilExit()
            let data = stdout.fileHandleForReading.readDataToEndOfFile()
            return (String(data: data, encoding: .utf8) ?? "", process.terminationStatus)
        } catch {
            return ("", -1)
        }
    }
}

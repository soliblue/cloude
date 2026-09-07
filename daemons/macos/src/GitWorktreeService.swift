import Foundation

enum GitWorktreeService {
    private static let queue = DispatchQueue(label: "app.afto.git.worktrees")

    static func branches(path: String) -> [String: Any]? {
        let cwd = URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
        let (text, code) = GitProcess.run(
            ["for-each-ref", "--format=%(refname:short)%00%(HEAD)", "refs/heads"], cwd: cwd)
        if code == 0 {
            let branches: [[String: Any]] = text.split(separator: "\n").compactMap { line in
                let fields = line.split(separator: "\0", omittingEmptySubsequences: false)
                return fields.count == 2 ? ["name": String(fields[0]), "current": fields[1] == "*"] : nil
            }
            let remote = GitProcess.run(["symbolic-ref", "--quiet", "--short", "refs/remotes/origin/HEAD"], cwd: cwd).0
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let current = branches.first { $0["current"] as? Bool == true }?["name"] as? String
            return ["branches": branches, "defaultBranch": remote.isEmpty ? current ?? "HEAD" : remote]
        }
        return nil
    }

    static func list(path: String) -> [[String: Any]]? {
        let cwd = URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
        let (text, code) = GitProcess.run(["worktree", "list", "--porcelain", "-z"], cwd: cwd)
        if code == 0 {
            var result: [[String: Any]] = []
            var entry: [String: Any] = [:]
            for record in text.components(separatedBy: "\0") {
                if record.isEmpty {
                    if !entry.isEmpty {
                        result.append(entry)
                        entry = [:]
                    }
                } else if record.hasPrefix("worktree ") {
                    entry = [
                        "path": String(record.dropFirst(9)), "branch": NSNull(), "head": "", "isMain": result.isEmpty,
                        "locked": false, "prunable": false,
                    ]
                } else if record.hasPrefix("HEAD ") {
                    entry["head"] = String(record.dropFirst(5))
                } else if record.hasPrefix("branch ") {
                    let branch = String(record.dropFirst(7))
                    entry["branch"] = branch.hasPrefix("refs/heads/") ? String(branch.dropFirst(11)) : branch
                } else if record == "locked" || record.hasPrefix("locked ") {
                    entry["locked"] = true
                } else if record == "prunable" || record.hasPrefix("prunable ") {
                    entry["prunable"] = true
                }
            }
            if !entry.isEmpty { result.append(entry) }
            return result
        }
        return nil
    }

    static func create(
        path: String, branch: String, baseRef: String = "HEAD", requestId: String
    ) -> (Int, [String: Any]) {
        queue.sync {
            let cwd = URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
            if let id = UUID(uuidString: requestId), !branch.hasPrefix("-"), !branch.contains("\0"),
                !baseRef.contains("\0"),
                GitProcess.run(["check-ref-format", "--branch", branch], cwd: cwd).1 == 0
            {
                let (common, commonCode) = GitProcess.run(
                    ["rev-parse", "--path-format=absolute", "--git-common-dir"], cwd: cwd)
                if commonCode == 0 {
                    let directory = CodexSessionStore.directory.resolvingSymlinksInPath().appendingPathComponent(
                        "worktrees")
                    let target = directory.appendingPathComponent(id.uuidString.lowercased())
                    let receipt = directory.appendingPathComponent(id.uuidString.lowercased() + ".json")
                    var metadata = [
                        "repository": URL(fileURLWithPath: common.trimmingCharacters(in: .whitespacesAndNewlines))
                            .resolvingSymlinksInPath().path, "branch": branch, "baseRef": baseRef,
                    ]
                    if let data = try? Data(contentsOf: receipt) {
                        if let previous = try? JSONDecoder().decode([String: String].self, from: data),
                            previous["repository"] == metadata["repository"], previous["branch"] == branch,
                            previous["baseRef"] == baseRef, let commit = previous["commit"], !commit.isEmpty
                        {
                            metadata["commit"] = commit
                            if let existing = list(path: cwd.path)?.first(where: {
                                ($0["path"] as? String).map { URL(fileURLWithPath: $0).resolvingSymlinksInPath().path }
                                    == target.resolvingSymlinksInPath().path
                            }) {
                                if existing["branch"] as? String == branch {
                                    return (
                                        200,
                                        [
                                            "path": existing["path"] ?? target.path, "branch": branch,
                                            "head": existing["head"] ?? "",
                                        ]
                                    )
                                }
                                return (
                                    409,
                                    [
                                        "error":
                                            "The worktree for this request has changed. Refresh your worktrees before continuing."
                                    ]
                                )
                            }
                        } else {
                            return (409, ["error": "This creation request was already used with different settings."])
                        }
                    }
                    if GitProcess.run(["show-ref", "--verify", "--quiet", "refs/heads/\(branch)"], cwd: cwd).1 == 0 {
                        return (409, ["error": "That branch already exists. Choose a new branch name."])
                    }
                    if metadata["commit"] == nil {
                        let (commit, code) = GitProcess.run(
                            ["rev-parse", "--verify", "--end-of-options", "\(baseRef)^{commit}"], cwd: cwd)
                        if code == 0 {
                            metadata["commit"] = commit.trimmingCharacters(in: .whitespacesAndNewlines)
                        }
                    }
                    if metadata["commit"] == nil {
                        return (400, ["error": "Choose a base revision containing a commit."])
                    }
                    if !FileManager.default.fileExists(atPath: target.path),
                        (try? FileManager.default.createDirectory(
                            at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700]))
                            != nil,
                        let data = try? JSONEncoder().encode(metadata),
                        (try? data.write(to: receipt, options: .atomic)) != nil
                    {
                        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: receipt.path)
                        let (_, code) = GitProcess.run(
                            [
                                "-c", "core.hooksPath=/dev/null", "worktree", "add", "-b", branch, "--", target.path,
                                metadata["commit"]!,
                            ], cwd: cwd)
                        if code == 0,
                            let existing = list(path: cwd.path)?.first(where: {
                                ($0["path"] as? String).map { URL(fileURLWithPath: $0).resolvingSymlinksInPath().path }
                                    == target.resolvingSymlinksInPath().path && $0["branch"] as? String == branch
                            })
                        {
                            return (
                                200,
                                [
                                    "path": existing["path"] ?? target.path, "branch": branch,
                                    "head": existing["head"] ?? "",
                                ]
                            )
                        }
                        return (
                            409,
                            [
                                "error":
                                    "Git could not create the worktree. Check disk space and host permissions, then retry this request."
                            ]
                        )
                    }
                    return (
                        409,
                        [
                            "error":
                                "The worktree destination is unavailable. Check the host and choose a new creation request."
                        ]
                    )
                }
                return (400, ["error": "Choose a Git repository and a base revision containing a commit."])
            }
            return (400, ["error": "Enter a valid new branch name and creation request ID."])
        }
    }
}

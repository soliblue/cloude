import Foundation
import CloudeShared

struct GitService {
    static func isGitRepository(at path: String) -> Bool {
        let gitDir = path.appendingPathComponent(".git")
        return FileManager.default.fileExists(atPath: gitDir)
    }

    static func getStatus(at path: String) -> Result<GitStatusInfo, Error> {
        guard isGitRepository(at: path) else {
            return .failure(GitError.notARepository)
        }

        let branch = runGit(["branch", "--show-current"], at: path).trimmingCharacters(in: .whitespacesAndNewlines)
        let (ahead, behind) = getAheadBehind(at: path)
        let files = parseStatus(runGit(["status", "--porcelain"], at: path))

        return .success(GitStatusInfo(branch: branch, ahead: ahead, behind: behind, files: files))
    }

    static func getDiff(at path: String, file: String?) -> Result<String, Error> {
        guard isGitRepository(at: path) else {
            return .failure(GitError.notARepository)
        }

        var args = ["diff"]
        if let file = file {
            args.append(file)
        }

        let diff = runGit(args, at: path)
        return .success(diff)
    }

    static func commit(at path: String, message: String, files: [String]) -> Result<String, Error> {
        guard isGitRepository(at: path) else {
            return .failure(GitError.notARepository)
        }

        for file in files {
            _ = runGit(["add", file], at: path)
        }

        let output = runGit(["commit", "-m", message], at: path)
        return .success(output)
    }

    private static func runGit(_ args: [String], at path: String) -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = args
        process.currentDirectoryURL = URL(fileURLWithPath: path)

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8) ?? ""
        } catch {
            return ""
        }
    }

    private static func getAheadBehind(at path: String) -> (Int, Int) {
        let output = runGit(["rev-list", "--left-right", "--count", "origin/HEAD...HEAD"], at: path)
        let parts = output.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: "\t")
        guard parts.count == 2,
              let behind = Int(parts[0]),
              let ahead = Int(parts[1]) else {
            return (0, 0)
        }
        return (ahead, behind)
    }

    private static func parseStatus(_ output: String) -> [GitFileStatus] {
        output.split(separator: "\n").compactMap { line in
            let line = String(line)
            guard line.count > 3 else { return nil }
            let status = String(line.prefix(2)).trimmingCharacters(in: .whitespaces)
            let path = String(line.dropFirst(3))
            return GitFileStatus(status: status.isEmpty ? "??" : status, path: path)
        }
    }
}

enum GitError: LocalizedError {
    case notARepository

    var errorDescription: String? {
        switch self {
        case .notARepository:
            return "Not a git repository"
        }
    }
}

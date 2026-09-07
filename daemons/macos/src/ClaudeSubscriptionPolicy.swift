import CoreFoundation
import Foundation

enum ClaudeSubscriptionPolicy {
    static let settings = "{\"forceLoginMethod\":\"claudeai\"}"

    static func settingsRejection(_ settings: [String: Any]) -> String? {
        let environment = settings["env"] as? [String: Any] ?? [:]
        let credentials = ["ANTHROPIC_API_KEY", "ANTHROPIC_AUTH_TOKEN", "ANTHROPIC_BASE_URL", "ANTHROPIC_PROFILE"]
        let providers = ["CLAUDE_CODE_USE_BEDROCK", "CLAUDE_CODE_USE_VERTEX", "CLAUDE_CODE_USE_FOUNDRY"]
        if let helper = settings["apiKeyHelper"] ?? settings["policyHelper"], !(helper is NSNull),
            String(describing: helper) != ""
        {
            return "Remove the Claude API credential helper to use subscription-only mode."
        }
        if let method = settings["forceLoginMethod"] as? String, !method.isEmpty, method != "claudeai" {
            return "Claude must use its Claude.ai subscription login. Console and gateway billing are not supported."
        }
        for key in credentials {
            if let value = environment[key], !(value is NSNull), String(describing: value) != "" {
                return
                    "Claude settings contain an API credential or inference endpoint override. Remove it to use subscription-only mode."
            }
        }
        for key in providers {
            if let value = environment[key], !(value is NSNull),
                !["", "0", "false"].contains(String(describing: value).lowercased())
            {
                return
                    "Claude cloud-provider billing is not supported. Disable the provider override to use your subscription."
            }
        }
        return nil
    }

    static func accountRejection(_ account: [String: Any]) -> String? {
        if account["loggedIn"] as? Bool == true,
            account["authMethod"] as? String == "claude.ai",
            account["apiProvider"] as? String == "firstParty",
            let subscription = account["subscriptionType"] as? String, !subscription.isEmpty,
            account["apiKeySource"] == nil || account["apiKeySource"] is NSNull
                || account["apiKeySource"] as? String == ""
        {
            return nil
        }
        return
            "Sign in to Claude Code with your Claude subscription. API keys, credential helpers and cloud-provider billing are not supported."
    }

    static func configurationRejection(
        cwd: String,
        home: String = FileManager.default.homeDirectoryForCurrentUser.path,
        managedPaths: [String] = [
            "/etc/claude-code/managed-settings.json",
            "/Library/Application Support/ClaudeCode/managed-settings.json",
        ],
        managedPreferences: [String: Any] = managedSettings()
    ) -> String? {
        if let rejection = settingsRejection(managedPreferences) { return rejection }
        var files = managedPaths + [URL(fileURLWithPath: home).appendingPathComponent(".claude/settings.json").path]
        for managedPath in managedPaths {
            let directory = URL(fileURLWithPath: managedPath).deletingLastPathComponent().appendingPathComponent(
                "managed-settings.d")
            if FileManager.default.fileExists(atPath: directory.path) {
                if let entries = try? FileManager.default.contentsOfDirectory(
                    at: directory, includingPropertiesForKeys: nil)
                {
                    files += entries.filter { $0.pathExtension == "json" && !$0.lastPathComponent.hasPrefix(".") }.map(
                        \.path)
                } else {
                    return "Managed Claude settings could not be read for subscription-only mode."
                }
            }
        }
        var directory = URL(fileURLWithPath: cwd).standardizedFileURL.resolvingSymlinksInPath()
        while directory.path != "/" {
            files.append(directory.appendingPathComponent(".claude/settings.json").path)
            files.append(directory.appendingPathComponent(".claude/settings.local.json").path)
            directory.deleteLastPathComponent()
        }
        files.append("/.claude/settings.json")
        files.append("/.claude/settings.local.json")
        for file in Set(files) where FileManager.default.fileExists(atPath: file) {
            if let data = try? Data(contentsOf: URL(fileURLWithPath: file)),
                let settings = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            {
                if let rejection = settingsRejection(settings) { return rejection }
            } else {
                return
                    "Claude settings could not be verified for subscription-only mode. Fix unreadable or invalid settings before continuing."
            }
        }
        return nil
    }

    static func managedSettings() -> [String: Any] {
        var settings: [String: Any] = [:]
        for key in ["env", "apiKeyHelper", "forceLoginMethod", "policyHelper"] {
            if let value = CFPreferencesCopyAppValue(key as CFString, "com.anthropic.claudecode" as CFString) {
                settings[key] = value
            }
        }
        return settings
    }

    static func authenticate(
        executable: String, leadingArguments: [String], cwd: String,
        environment: [String: String], timeout: TimeInterval = 15
    ) -> String? {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
            "afto-claude-auth-\(UUID().uuidString)")
        if (try? FileManager.default.createDirectory(
            at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])) == nil
        {
            return "Unable to prepare the Claude subscription check."
        }
        defer { try? FileManager.default.removeItem(at: directory) }
        let output = directory.appendingPathComponent("status.json")
        if FileManager.default.createFile(atPath: output.path, contents: nil, attributes: [.posixPermissions: 0o600]),
            let handle = try? FileHandle(forWritingTo: output)
        {
            defer { try? handle.close() }
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = leadingArguments + ["--settings", settings, "auth", "status"]
            process.currentDirectoryURL = URL(fileURLWithPath: cwd)
            process.environment = environment
            process.standardInput = FileHandle.nullDevice
            process.standardOutput = handle
            process.standardError = FileHandle.nullDevice
            if (try? process.run()) != nil {
                let deadline = DispatchWorkItem {
                    if process.isRunning { kill(process.processIdentifier, SIGKILL) }
                }
                DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + timeout, execute: deadline)
                process.waitUntilExit()
                deadline.cancel()
                if process.terminationStatus == 0,
                    let size = try? output.resourceValues(forKeys: [.fileSizeKey]).fileSize, size <= 1024 * 1024,
                    let data = try? Data(contentsOf: output),
                    let account = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                {
                    return accountRejection(account)
                }
            }
        }
        return "Unable to verify Claude subscription login. Run claude auth login on this endpoint and retry."
    }

    static func environment(
        inherited: [String: String] = ProcessInfo.processInfo.environment,
        home: String = FileManager.default.homeDirectoryForCurrentUser.path
    ) -> [String: String] {
        var environment: [String: String] = [:]
        for key in ["HOME", "USER", "SHELL", "LANG", "LC_ALL", "TMPDIR", "TERM"] {
            if let value = inherited[key] { environment[key] = value }
        }
        var directories = (inherited["PATH"] ?? "").split(separator: ":").map(String.init)
        for extra in [
            "/opt/homebrew/bin", "/usr/local/bin", "/usr/bin", "\(home)/.local/bin", "\(home)/.npm-global/bin",
        ]
        where !directories.contains(extra) {
            directories.append(extra)
        }
        environment["HOME"] = environment["HOME"] ?? home
        environment["PATH"] = directories.joined(separator: ":")
        environment["TERM"] = environment["TERM"] ?? "xterm-256color"
        environment["NO_COLOR"] = "1"
        environment["CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS"] = "1"
        return environment
    }
}

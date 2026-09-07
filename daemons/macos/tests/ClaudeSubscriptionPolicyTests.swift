import Foundation

@main
struct ClaudeSubscriptionPolicyTests {
    static func main() throws {
        if CommandLine.arguments.contains("--fixture") {
            let mode = CommandLine.arguments[2]
            if !CommandLine.arguments.contains(ClaudeSubscriptionPolicy.settings)
                || Array(CommandLine.arguments.suffix(2)) != ["auth", "status"]
                || ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] != nil
            {
                exit(2)
            }
            if mode == "slow" { Thread.sleep(forTimeInterval: 5) }
            if mode == "malformed" {
                print("not-json")
                return
            }
            if mode == "oversized" {
                print(String(repeating: "x", count: 1024 * 1024 + 1))
                return
            }
            var account: [String: Any] = [
                "loggedIn": true, "authMethod": "claude.ai", "apiProvider": "firstParty", "subscriptionType": "max",
            ]
            if mode == "api" { account["apiKeySource"] = "ANTHROPIC_API_KEY" }
            if mode == "logged-out" { account["loggedIn"] = false }
            FileHandle.standardOutput.write(try JSONSerialization.data(withJSONObject: account))
            return
        }

        let root = FileManager.default.temporaryDirectory.appendingPathComponent(
            "afto-claude-policy-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let home = root.appendingPathComponent("home")
        let workspace = root.appendingPathComponent("project/nested")
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: workspace, withIntermediateDirectories: true)

        precondition(ClaudeSubscriptionPolicy.settingsRejection([:]) == nil)
        precondition(ClaudeSubscriptionPolicy.settingsRejection(["forceLoginMethod": "claudeai"]) == nil)
        for key in ["ANTHROPIC_API_KEY", "ANTHROPIC_AUTH_TOKEN", "ANTHROPIC_BASE_URL", "ANTHROPIC_PROFILE"] {
            precondition(ClaudeSubscriptionPolicy.settingsRejection(["env": [key: "fixture-value"]]) != nil)
        }
        for key in ["CLAUDE_CODE_USE_BEDROCK", "CLAUDE_CODE_USE_VERTEX", "CLAUDE_CODE_USE_FOUNDRY"] {
            precondition(ClaudeSubscriptionPolicy.settingsRejection(["env": [key: "1"]]) != nil)
            precondition(ClaudeSubscriptionPolicy.settingsRejection(["env": [key: false]]) == nil)
        }
        precondition(ClaudeSubscriptionPolicy.settingsRejection(["apiKeyHelper": "credential-script"]) != nil)
        precondition(ClaudeSubscriptionPolicy.settingsRejection(["forceLoginMethod": "console"]) != nil)
        precondition(ClaudeSubscriptionPolicy.settingsRejection(["forceLoginMethod": "gateway"]) != nil)

        let account: [String: Any] = [
            "loggedIn": true, "authMethod": "claude.ai", "apiProvider": "firstParty", "subscriptionType": "max",
        ]
        precondition(ClaudeSubscriptionPolicy.accountRejection(account) == nil)
        for override in [
            ["loggedIn": false], ["authMethod": "api_key"], ["apiProvider": "bedrock"],
            ["apiKeySource": "ANTHROPIC_API_KEY"], ["subscriptionType": ""],
        ] as [[String: Any]] {
            precondition(ClaudeSubscriptionPolicy.accountRejection(account.merging(override) { _, new in new }) != nil)
        }

        let environment = ClaudeSubscriptionPolicy.environment(
            inherited: [
                "HOME": home.path, "PATH": "/usr/bin", "USER": "fixture", "ANTHROPIC_API_KEY": "never-forward",
                "ANTHROPIC_AUTH_TOKEN": "never-forward", "CLAUDE_CODE_USE_BEDROCK": "1",
                "OPENAI_API_KEY": "never-forward", "AWS_ACCESS_KEY_ID": "never-forward",
                "CLAUDE_CONFIG_DIR": "/alternate-unverified-config",
            ], home: home.path)
        for key in [
            "ANTHROPIC_API_KEY", "ANTHROPIC_AUTH_TOKEN", "CLAUDE_CODE_USE_BEDROCK", "OPENAI_API_KEY",
            "AWS_ACCESS_KEY_ID", "CLAUDE_CONFIG_DIR",
        ] {
            precondition(environment[key] == nil)
        }
        precondition(environment["HOME"] == home.path)
        precondition(environment["PATH"]?.contains("\(home.path)/.local/bin") == true)
        precondition(
            ClaudeSubscriptionPolicy.configurationRejection(
                cwd: workspace.path, home: home.path, managedPaths: [], managedPreferences: [:])
                == nil)

        precondition(
            ClaudeSubscriptionPolicy.configurationRejection(
                cwd: workspace.path, home: home.path, managedPaths: [],
                managedPreferences: ["env": ["ANTHROPIC_AUTH_TOKEN": "managed-token"]]) != nil)

        let projectSettings = root.appendingPathComponent("project/.claude/settings.local.json")
        try FileManager.default.createDirectory(
            at: projectSettings.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("{\"env\":{\"ANTHROPIC_API_KEY\":\"project-key\"}}".utf8).write(to: projectSettings)
        precondition(
            ClaudeSubscriptionPolicy.configurationRejection(
                cwd: workspace.path, home: home.path, managedPaths: [], managedPreferences: [:])
                != nil)
        let alias = root.appendingPathComponent("workspace-alias")
        try FileManager.default.createSymbolicLink(at: alias, withDestinationURL: workspace)
        precondition(
            ClaudeSubscriptionPolicy.configurationRejection(
                cwd: alias.path, home: home.path, managedPaths: [], managedPreferences: [:]) != nil)
        try Data("{".utf8).write(to: projectSettings)
        precondition(
            ClaudeSubscriptionPolicy.configurationRejection(
                cwd: workspace.path, home: home.path, managedPaths: [], managedPreferences: [:])
                != nil)
        try FileManager.default.removeItem(at: projectSettings)
        let managed = root.appendingPathComponent("managed-settings.json")
        try Data("{\"apiKeyHelper\":\"fixture\"}".utf8).write(to: managed)
        precondition(
            ClaudeSubscriptionPolicy.configurationRejection(
                cwd: workspace.path, home: home.path, managedPaths: [managed.path], managedPreferences: [:]) != nil)

        precondition(
            ClaudeSubscriptionPolicy.authenticate(
                executable: CommandLine.arguments[0], leadingArguments: ["--fixture", "valid"], cwd: workspace.path,
                environment: environment) == nil)
        for mode in ["api", "logged-out", "malformed", "oversized"] {
            precondition(
                ClaudeSubscriptionPolicy.authenticate(
                    executable: CommandLine.arguments[0], leadingArguments: ["--fixture", mode], cwd: workspace.path,
                    environment: environment) != nil)
        }
        let start = Date()
        precondition(
            ClaudeSubscriptionPolicy.authenticate(
                executable: CommandLine.arguments[0], leadingArguments: ["--fixture", "slow"], cwd: workspace.path,
                environment: environment, timeout: 0.05) != nil)
        precondition(Date().timeIntervalSince(start) < 2)
        print(
            "Claude subscription policy: settings, account, environment, inherited project configuration, auth subprocess and timeout checks passed"
        )
    }
}

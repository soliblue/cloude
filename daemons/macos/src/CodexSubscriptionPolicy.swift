import CoreFoundation
import Foundation

enum CodexSubscriptionPolicy {
    private static let capacityError = "Unable to verify subscription capacity. Check the host account and retry."

    static func rejection(
        account: [String: Any], config: [String: Any], limits: [String: Any], requireCapacity: Bool = true
    ) -> String? {
        if (account["account"] as? [String: Any])?["type"] as? String != "chatgpt" {
            return "Sign in to Codex with your ChatGPT subscription. API key billing is not supported."
        }
        let settings = config["config"] as? [String: Any] ?? [:]
        if let providers = settings["model_providers"] as? [String: Any],
            let openai = providers["openai"] as? [String: Any], !openai.isEmpty
        {
            return "Remove custom OpenAI provider settings to use subscription-only mode."
        }
        for (key, host, prefix) in [
            ("chatgpt_base_url", "chatgpt.com", "/backend-api"), ("openai_base_url", "api.openai.com", "/v1"),
        ] {
            if let value = settings[key] as? String {
                if let url = URLComponents(string: value), url.scheme?.lowercased() == "https",
                    url.host?.lowercased() == host,
                    url.port == nil, url.user == nil, url.password == nil, url.query == nil,
                    [prefix, prefix + "/", prefix + "/codex"].contains(url.path)
                {
                } else {
                    return "Custom inference endpoints cannot be used in subscription-only mode."
                }
            }
        }
        if !requireCapacity { return nil }
        let quota =
            (limits["rateLimitsByLimitId"] as? [String: Any])?["codex"] as? [String: Any]
            ?? limits["rateLimits"] as? [String: Any]
        guard let quota else { return capacityError }
        let windows = [quota["primary"], quota["secondary"]].compactMap { value -> [String: Any]? in
            guard let value, !(value is NSNull) else { return nil }
            return value as? [String: Any] ?? [:]
        }
        guard !windows.isEmpty else { return capacityError }
        let usages = windows.map { window -> Double? in
            guard let value = window["usedPercent"], !(value is NSNull), let number = value as? NSNumber,
                CFGetTypeID(number) != CFBooleanGetTypeID()
            else { return nil }
            let amount = number.doubleValue
            return amount.isFinite && amount >= 0 ? amount : nil
        }
        guard usages.allSatisfy({ $0 != nil }) else { return capacityError }
        if usages.contains(where: { $0 ?? 0 >= 100 }) {
            return "Codex subscription limit reached. Wait for its reset; paid credits are not used by this app."
        }
        return nil
    }
}

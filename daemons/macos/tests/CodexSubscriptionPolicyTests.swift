import Foundation

@main
struct CodexSubscriptionPolicyTests {
    static func baseLimits() -> [String: Any] {
        ["rateLimits": ["primary": ["usedPercent": 20.0], "secondary": ["usedPercent": 30.0]]]
    }

    static func main() {
        let account: [String: Any] = ["account": ["type": "chatgpt"]]
        let config: [String: Any] = ["config": [:]]
        precondition(
            CodexSubscriptionPolicy.rejection(account: account, config: config, limits: [:], requireCapacity: false)
                == nil)
        precondition(
            CodexSubscriptionPolicy.rejection(
                account: account, config: config, limits: ["rateLimits": ["primary": ["usedPercent": 100.0]]],
                requireCapacity: false) == nil)
        precondition(
            CodexSubscriptionPolicy.rejection(
                account: ["account": ["type": "apiKey"]], config: config, limits: [:], requireCapacity: false) != nil)
        precondition(
            CodexSubscriptionPolicy.rejection(
                account: account,
                config: ["config": ["model_providers": ["openai": ["base_url": "https://paid.example"]]]], limits: [:],
                requireCapacity: false) != nil)
        precondition(CodexSubscriptionPolicy.rejection(account: account, config: config, limits: baseLimits()) == nil)
        precondition(
            CodexSubscriptionPolicy.rejection(
                account: account, config: config, limits: ["rateLimits": ["primary": ["usedPercent": 100.0]]])?
                .contains("limit reached") == true)
        for value: Any in [-1.0, Double.nan, Double.infinity, "20", true, NSNull()] {
            precondition(
                CodexSubscriptionPolicy.rejection(
                    account: account, config: config, limits: ["rateLimits": ["primary": ["usedPercent": value]]])
                    != nil)
        }
        precondition(
            CodexSubscriptionPolicy.rejection(
                account: account, config: config,
                limits: ["rateLimits": ["primary": ["usedPercent": 10.0], "secondary": ["unavailable": true]]]) != nil)
        precondition(
            CodexSubscriptionPolicy.rejection(
                account: account, config: config,
                limits: ["rateLimits": ["primary": NSNull(), "secondary": ["usedPercent": 10.0]]]) == nil)
        precondition(
            CodexSubscriptionPolicy.rejection(
                account: account, config: config,
                limits: ["rateLimitsByLimitId": ["codex": ["primary": ["usedPercent": 10.0]]]]) == nil)
        precondition(
            CodexSubscriptionPolicy.rejection(
                account: account, config: config,
                limits: ["rateLimitsByLimitId": ["codex": ["primary": ["usedPercent": -0.1]]]]) != nil)
        precondition(
            CodexSubscriptionPolicy.rejection(
                account: account,
                config: ["config": ["model_providers": ["openai": ["base_url": "https://paid.example"]]]],
                limits: baseLimits()) != nil)
        precondition(
            CodexSubscriptionPolicy.rejection(
                account: account, config: ["config": ["openai_base_url": "https://api.openai.com/v1"]],
                limits: baseLimits()) == nil)
        precondition(
            CodexSubscriptionPolicy.rejection(
                account: account, config: ["config": ["openai_base_url": "https://api.openai.com/v1?paid=true"]],
                limits: baseLimits()) != nil)
        precondition(
            CodexSubscriptionPolicy.rejection(
                account: ["account": ["type": "apiKey"]], config: config, limits: baseLimits()) != nil)
        print("Codex subscription policy: strict account, provider, endpoint and quota validation passed")
    }
}

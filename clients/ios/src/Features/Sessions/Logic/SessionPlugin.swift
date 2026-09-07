import Foundation

nonisolated struct SessionPlugin: Decodable, Sendable, Identifiable {
    let id: String
    let name: String
    let installed: Bool
    let enabled: Bool
    let installPolicy: String
    let authPolicy: String
    let availability: String?
    let disabledReason: String?
    let installPolicySource: String?
    let mustShowInstallationInterstitial: Bool?
    let interface: SessionPluginInterface?

    var displayName: String { interface?.displayName ?? name }
    var canInstall: Bool {
        !installed && installPolicy == "AVAILABLE" && (availability == nil || availability == "AVAILABLE")
            && disabledReason == nil
    }
    var policyDescription: String? {
        switch disabledReason {
        case "plan_not_eligible": "Unavailable on this subscription"
        case "required_app_unavailable": "A required app is unavailable"
        case "disabled_by_admin": "Disabled by your administrator"
        case .some: "Unavailable on this machine"
        case nil:
            availability == "DISABLED_BY_ADMIN"
                ? "Disabled by your administrator"
                : installPolicy == "NOT_AVAILABLE"
                    ? "Installation unavailable"
                    : installPolicySource == "WORKSPACE_SETTING" ? "Managed by your workspace" : nil
        }
    }
}

import Combine
import Foundation

@MainActor
final class RemoteTunnelProvisioner: ObservableObject {
    static let shared = RemoteTunnelProvisioner()

    @Published private(set) var steps = RemoteTunnelStep.allCases.map {
        RemoteTunnelStepState(step: $0, status: .waiting)
    }
    @Published private(set) var endpoint: RemoteTunnelEndpoint?
    @Published private(set) var errorMessage: String?
    @Published private(set) var isRunning = false

    func start() async {
        if !isRunning && endpoint == nil {
            isRunning = true
            errorMessage = nil
            steps = RemoteTunnelStep.allCases.map { RemoteTunnelStepState(step: $0, status: .waiting) }

            set(.identity, status: .active)
            let identity = RemoteTunnelCredentialStore.identity
            set(.identity, status: .complete)

            set(.auth, status: .active)
            let authToken = DaemonAuth.token
            set(.auth, status: .complete)

            set(.provisioning, status: .active)
            if await RemoteTunnelClient.putMac(identity: identity),
                let tunnel = await RemoteTunnelClient.putTunnel(identity: identity)
            {
                RemoteTunnelCredentialStore.save(tunnel: tunnel)
                set(.provisioning, status: .complete)
                await runTunnel(
                    host: tunnel.hostname, token: tunnel.tunnelToken, authToken: authToken,
                    publishBeforeReachability: true)
            } else if let host = RemoteTunnelCredentialStore.tunnelHost,
                let token = RemoteTunnelCredentialStore.tunnelToken
            {
                set(.provisioning, status: .complete)
                await runTunnel(
                    host: host, token: token, authToken: authToken,
                    publishBeforeReachability: false)
            } else {
                fail(.provisioning, "Provisioning server did not return a tunnel")
            }

            isRunning = false
        }
    }

    private func runTunnel(
        host: String, token: String, authToken: String, publishBeforeReachability: Bool
    ) async {
        set(.tunnel, status: .active)
        if CloudflaredRunner.shared.start(token: token) {
            set(.tunnel, status: .complete)

            let remoteEndpoint = RemoteTunnelEndpoint(host: host, port: 443)
            if publishBeforeReachability { endpoint = remoteEndpoint }

            set(.reachability, status: .active)
            if await RemoteTunnelClient.isPublicRouteReady(
                endpoint: remoteEndpoint,
                authToken: authToken
            ) {
                endpoint = remoteEndpoint
                set(.reachability, status: .complete)
            } else if publishBeforeReachability {
                fail(.reachability, "Public route is not ready yet")
            } else {
                CloudflaredRunner.shared.stop()
                fail(.provisioning, "Saved tunnel is no longer reachable")
            }
        } else {
            fail(.tunnel, "cloudflared is not available")
        }
    }

    private func set(_ step: RemoteTunnelStep, status: RemoteTunnelStepStatus) {
        steps = steps.map {
            $0.step == step ? RemoteTunnelStepState(step: $0.step, status: status) : $0
        }
    }

    private func fail(_ step: RemoteTunnelStep, _ message: String) {
        set(step, status: .failed)
        errorMessage = message
    }
}

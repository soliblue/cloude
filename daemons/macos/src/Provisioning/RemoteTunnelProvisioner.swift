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

                set(.tunnel, status: .active)
                if CloudflaredRunner.shared.start(token: tunnel.tunnelToken) {
                    set(.tunnel, status: .complete)

                    let remoteEndpoint = RemoteTunnelEndpoint(host: tunnel.hostname, port: 443)
                    endpoint = remoteEndpoint

                    set(.reachability, status: .active)
                    if await RemoteTunnelClient.isPublicRouteReady(
                        endpoint: remoteEndpoint,
                        authToken: authToken
                    ) {
                        set(.reachability, status: .complete)
                    } else {
                        fail(.reachability, "Public route is not ready yet")
                    }
                } else {
                    fail(.tunnel, "cloudflared is not available")
                }
            } else {
                fail(.provisioning, "Provisioning server did not return a tunnel")
            }

            isRunning = false
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

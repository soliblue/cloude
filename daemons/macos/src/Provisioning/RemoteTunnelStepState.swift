import Foundation

struct RemoteTunnelStepState: Identifiable {
    let step: RemoteTunnelStep
    var status: RemoteTunnelStepStatus

    var id: RemoteTunnelStep {
        step
    }
}

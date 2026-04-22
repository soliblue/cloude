import Foundation
import SwiftData

@Observable
@MainActor
final class OnboardingStore {
    var step: OnboardingStep = .install
    var draft: OnboardingPairingPayload?
    var probeResult: EndpointProbeResult?
    var isProbing = false

    func apply(payload: OnboardingPairingPayload) {
        draft = payload
        probeResult = nil
        step = .status
    }

    func reset() {
        draft = nil
        probeResult = nil
        isProbing = false
        step = .pair
    }

    func verifyAndSave(context: ModelContext) async -> Endpoint? {
        if let draft {
            isProbing = true
            let result = await EndpointService.probe(
                host: draft.host,
                port: draft.port,
                authKey: draft.token,
                retryWindow: 6
            )
            isProbing = false
            probeResult = result
            if result == .reachable {
                let host = draft.host
                let port = draft.port
                let fetch = FetchDescriptor<Endpoint>(
                    predicate: #Predicate { $0.host == host && $0.port == port }
                )
                if let existing = (try? context.fetch(fetch))?.first {
                    EndpointActions.update(
                        existing,
                        host: host,
                        port: port,
                        name: draft.name,
                        symbolName: existing.symbolName,
                        authKey: draft.token
                    )
                    return existing
                }
                return EndpointActions.create(
                    into: context,
                    host: host,
                    port: port,
                    name: draft.name,
                    symbolName: Endpoint.defaultSymbol,
                    authKey: draft.token
                )
            }
        }
        return nil
    }
}

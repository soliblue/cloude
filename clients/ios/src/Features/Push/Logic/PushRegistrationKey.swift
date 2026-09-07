import Foundation

struct PushRegistrationKey: Hashable {
    let endpointId: UUID
    let revision: UUID
    let token: String
}

import Observation

@Observable
final class SessionForkStore {
    var isForking = false
    var error: String?
}

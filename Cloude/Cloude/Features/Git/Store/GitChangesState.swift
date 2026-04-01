import Foundation
import Combine
import CloudeShared

@MainActor
class GitChangesState: ObservableObject {
    @Published var gitStatus: GitStatusInfo?
    @Published var isLoading = false
    @Published var isInitialLoad = true

    func applyStatus(_ status: GitStatusInfo) {
        gitStatus = status
        isLoading = false
        isInitialLoad = false
    }

    func applyError() {
        gitStatus = nil
        isLoading = false
        isInitialLoad = false
    }

    func beginLoading() {
        isLoading = true
    }

    func reset() {
        gitStatus = nil
        isLoading = false
        isInitialLoad = true
    }
}

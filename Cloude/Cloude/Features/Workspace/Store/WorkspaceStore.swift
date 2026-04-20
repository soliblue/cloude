import Foundation
import Combine

@MainActor
final class WorkspaceStore: ObservableObject {
    @Published var windowBeingEdited: Window?
    @Published var isKeyboardVisible = false
    @Published var isShowingConversationSearch = false
}

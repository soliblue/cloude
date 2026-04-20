import SwiftUI
import UIKit
import PhotosUI
import UniformTypeIdentifiers
import Combine
import CloudeShared

struct ConversationInputBar: View {
    @Binding var inputText: String
    @Binding var attachedImages: [AttachedImage]
    @Binding var attachedFiles: [AttachedFile]
    let isConnected: Bool
    let isWhisperReady: Bool
    let isTranscribing: Bool
    let isRunning: Bool
    let skills: [Skill]
    let fileSearchResults: [String]
    let environmentMismatch: Bool
    let isEnvironmentDisconnected: Bool
    let onSend: () -> Void
    var onStop: (() -> Void)?
    var onConnect: (() -> Void)?
    var onRefresh: (() -> Void)?
    var onTranscribe: ((Data) -> Void)?
    var onFileSearch: ((String) -> Void)?
    @Binding var currentEffort: EffortLevel?
    @Binding var currentModel: ModelSelection?

    @State var selectedItem: PhotosPickerItem?
    @State var isShowingPhotoPicker = false
    @State var isShowingFilePicker = false
    @FocusState var isInputFocused: Bool
    @StateObject var audioRecorder = AudioRecorder()
    @State var placeholderIndex = 0

    @State var swipeOffset: CGFloat = 0
    @State var horizontalSwipeOffset: CGFloat = 0
    @State var phase: InputBarPhase = .idle
    @State var idleTime: Date = Date()
    @State var isShowingStopButton = false
    @State var refreshRotateTrigger = 0
    @State var sendBounceTrigger = 0
    @State var fileSearchDebounce: Task<Void, Never>?

    enum Constants {
        static let swipeThreshold: CGFloat = 60
        static let transitionDuration: Double = 0.15
        static let stopButtonDelay: TimeInterval = 3.0
        static let fileSearchDebounce: Duration = .milliseconds(150)
        static let maxImageAttachments = 5
    }

    static let placeholders = [
        "Swipe up to record a voice note",
        "Type / to see available commands",
        "Hold send for images and files",
        "Swipe left on queued messages to delete",
        "Swipe left here to clear text",
        "Add multiple environments in settings",
        "Type @ to reference a file",
        "Tap the header to switch chats",
        "Browse files in the middle tab",
        "Try /compact to reduce context"
    ]
}

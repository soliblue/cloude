import SwiftUI

extension GlobalInputBar {
    var inputBarDragGesture: some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { value in
                let verticalDrag = -value.translation.height
                let horizontalDrag = -value.translation.width

                if verticalDrag > abs(horizontalDrag) && canRecord && !audioRecorder.isRecording {
                    isSwipingToRecord = true
                    swipeOffset = verticalDrag
                    horizontalSwipeOffset = 0
                } else if horizontalDrag > abs(verticalDrag) && !inputText.isEmpty {
                    horizontalSwipeOffset = horizontalDrag
                    swipeOffset = 0
                    isSwipingToRecord = false
                }
            }
            .onEnded { value in
                let verticalDrag = -value.translation.height
                let horizontalDrag = -value.translation.width

                if verticalDrag >= Constants.swipeThreshold && canRecord && isSwipingToRecord {
                    startRecording()
                } else if horizontalDrag >= Constants.swipeThreshold && !inputText.isEmpty {
                    withAnimation(.easeOut(duration: 0.15)) {
                        inputText = ""
                        attachedImages = []
                        attachedFiles = []
                    }
                }

                withAnimation(.easeOut(duration: 0.2)) {
                    swipeOffset = 0
                    horizontalSwipeOffset = 0
                    isSwipingToRecord = false
                }
            }
    }

    var canRecord: Bool {
        isConnected && isWhisperReady && !audioRecorder.isTranscribing
    }

    func startRecording() {
        audioRecorder.requestPermission { granted in
            if granted {
                UIApplication.shared.isIdleTimerDisabled = true
                withAnimation(.easeOut(duration: Constants.transitionDuration)) {
                    showInputBar = false
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + Constants.transitionDuration) {
                    audioRecorder.startRecording()
                    withAnimation(.easeOut(duration: Constants.transitionDuration)) {
                        showRecordingOverlay = true
                    }
                }
            }
        }
    }

    func stopRecording() {
        UIApplication.shared.isIdleTimerDisabled = false
        let data = audioRecorder.stopRecording()
        withAnimation(.easeOut(duration: Constants.transitionDuration)) {
            showRecordingOverlay = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + Constants.transitionDuration) {
            withAnimation(.easeOut(duration: Constants.transitionDuration)) {
                showInputBar = true
            }
            if let data = data {
                onTranscribe?(data)
            }
        }
    }

    func resendPendingAudio() {
        if let data = audioRecorder.pendingAudioData() {
            onTranscribe?(data)
        }
    }
}


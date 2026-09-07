import Foundation
import Speech

@MainActor final class ChatLocalTranscription {
    private static let availabilityRecognizer = SFSpeechRecognizer(locale: .current)
    static var available: Bool { availabilityRecognizer?.supportsOnDeviceRecognition == true }
    private var generation: UUID?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var continuation: CheckedContinuation<String?, Never>?
    private var authorization: CheckedContinuation<Bool, Never>?
    private var timeout: Task<Void, Never>?

    func transcribe(audio: Data) async -> String? {
        if let generation { finish(nil, generation: generation) }
        let generation = UUID()
        self.generation = generation
        return await withTaskCancellationHandler {
            if !Task.isCancelled, let recognizer = SFSpeechRecognizer(locale: .current),
                recognizer.supportsOnDeviceRecognition
            {
                let authorized = await withCheckedContinuation { continuation in
                    authorization = continuation
                    SFSpeechRecognizer.requestAuthorization { [weak self] status in
                        Task { @MainActor [weak self] in self?.authorize(status == .authorized, generation: generation)
                        }
                    }
                }
                if authorized && !Task.isCancelled && self.generation == generation,
                    let url = await ChatTranscriptionAudio.write(audio)
                {
                    if !Task.isCancelled && self.generation == generation {
                        let text = await withCheckedContinuation { continuation in
                            self.continuation = continuation
                            let request = SFSpeechURLRecognitionRequest(url: url)
                            request.requiresOnDeviceRecognition = true
                            request.shouldReportPartialResults = false
                            request.addsPunctuation = true
                            recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
                                let text = result?.isFinal == true ? result?.bestTranscription.formattedString : nil
                                if result?.isFinal == true || error != nil {
                                    Task { @MainActor [weak self] in self?.finish(text, generation: generation) }
                                }
                            }
                            timeout = Task {
                                try? await Task.sleep(for: .seconds(60))
                                if !Task.isCancelled { finish(nil, generation: generation) }
                            }
                        }
                        await ChatTranscriptionAudio.remove(url)
                        return Task.isCancelled ? nil : text
                    }
                    await ChatTranscriptionAudio.remove(url)
                }
            }
            finish(nil, generation: generation)
            return nil
        } onCancel: {
            Task { @MainActor in self.finish(nil, generation: generation) }
        }
    }

    private func authorize(_ allowed: Bool, generation: UUID) {
        if self.generation == generation, let authorization {
            self.authorization = nil
            authorization.resume(returning: allowed)
        }
    }

    private func finish(_ text: String?, generation: UUID) {
        if self.generation == generation {
            self.generation = nil
            let continuation = continuation
            let authorization = authorization
            self.continuation = nil
            self.authorization = nil
            timeout?.cancel()
            timeout = nil
            recognitionTask?.cancel()
            recognitionTask = nil
            authorization?.resume(returning: false)
            continuation?.resume(returning: text)
        }
    }
}

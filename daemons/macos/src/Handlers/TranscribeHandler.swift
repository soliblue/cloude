import Foundation
import Speech

enum TranscribeHandler {
    static func transcribe(_ request: HTTPRequest, params: [String: String]) -> HTTPResponse {
        if let body = try? JSONSerialization.jsonObject(with: request.body) as? [String: Any],
            let audioBase64 = body["audio"] as? String,
            let audioData = Data(base64Encoded: audioBase64), !audioData.isEmpty
        {
            if authorized(), let recognizer = availableRecognizer() {
                if let text = recognize(audioData: audioData, recognizer: recognizer) {
                    return HTTPResponse.json(200, ["text": text])
                }
                return HTTPResponse.json(500, ["error": "transcription_failed"])
            }
            return HTTPResponse.json(503, ["error": "transcription_unavailable"])
        }
        return HTTPResponse.json(400, ["error": "missing_audio"])
    }

    static func available() -> Bool {
        let status = SFSpeechRecognizer.authorizationStatus()
        return status != .denied && status != .restricted && availableRecognizer() != nil
    }

    private static func authorized() -> Bool {
        if SFSpeechRecognizer.authorizationStatus() == .notDetermined {
            let semaphore = DispatchSemaphore(value: 0)
            SFSpeechRecognizer.requestAuthorization { _ in semaphore.signal() }
            semaphore.wait()
        }
        return SFSpeechRecognizer.authorizationStatus() == .authorized
    }

    private static func availableRecognizer() -> SFSpeechRecognizer? {
        let recognizer = SFSpeechRecognizer() ?? SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        return recognizer?.isAvailable == true ? recognizer : nil
    }

    private static func recognize(audioData: Data, recognizer: SFSpeechRecognizer) -> String? {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("cloude-transcribe-\(UUID().uuidString).wav")
        if (try? audioData.write(to: url)) != nil {
            defer { try? FileManager.default.removeItem(at: url) }
            let recognitionRequest = SFSpeechURLRecognitionRequest(url: url)
            recognitionRequest.shouldReportPartialResults = false
            if recognizer.supportsOnDeviceRecognition {
                recognitionRequest.requiresOnDeviceRecognition = true
            }
            let semaphore = DispatchSemaphore(value: 0)
            var transcription: String?
            recognizer.recognitionTask(with: recognitionRequest) { result, error in
                if let result, result.isFinal {
                    transcription = result.bestTranscription.formattedString
                    semaphore.signal()
                }
                if let error {
                    NSLog("[TranscribeHandler] recognition error: \(error.localizedDescription)")
                    semaphore.signal()
                }
            }
            if semaphore.wait(timeout: .now() + 55) == .timedOut {
                NSLog("[TranscribeHandler] recognition timed out")
            }
            return transcription?.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return nil
    }
}

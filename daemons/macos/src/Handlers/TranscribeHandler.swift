import Foundation
import Speech

enum TranscribeHandler {
    private static let gate = NSLock()

    static func transcribe(
        _ request: HTTPRequest, params: [String: String], authorizationTimeout: TimeInterval = 10,
        recognitionTimeout: TimeInterval = 55
    ) -> HTTPResponse {
        if gate.try() {
            defer { gate.unlock() }
            if let body = try? JSONSerialization.jsonObject(with: request.body) as? [String: Any],
                let audioBase64 = body["audio"] as? String,
                let audioData = Data(base64Encoded: audioBase64), !audioData.isEmpty
            {
                if authorized(cancellation: request.cancellation, timeout: authorizationTimeout),
                    let recognizer = availableRecognizer()
                {
                    if let text = recognize(
                        audioData: audioData, recognizer: recognizer, cancellation: request.cancellation,
                        timeout: recognitionTimeout)
                    {
                        return HTTPResponse.json(200, ["text": text])
                    }
                    return HTTPResponse.json(500, ["error": "transcription_failed"])
                }
                return HTTPResponse.json(503, ["error": "transcription_unavailable"])
            }
            return HTTPResponse.json(400, ["error": "missing_audio"])
        }
        return HTTPResponse.json(429, ["error": "transcription_busy"])
    }

    static func available() -> Bool {
        let status = SFSpeechRecognizer.authorizationStatus()
        return status != .denied && status != .restricted && availableRecognizer() != nil
    }

    private static func authorized(cancellation: HTTPRequestCancellation, timeout: TimeInterval) -> Bool {
        if SFSpeechRecognizer.authorizationStatus() == .notDetermined {
            let operation = TranscriptionOperation<Bool>()
            cancellation.observe { operation.finish(nil) }
            defer { cancellation.stopObserving() }
            if !cancellation.isCancelled {
                SFSpeechRecognizer.requestAuthorization { operation.finish($0 == .authorized) }
            }
            return operation.wait(timeout: timeout) == true && !cancellation.isCancelled
        }
        return SFSpeechRecognizer.authorizationStatus() == .authorized && !cancellation.isCancelled
    }

    private static func availableRecognizer() -> SFSpeechRecognizer? {
        let recognizer = SFSpeechRecognizer() ?? SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        return recognizer?.isAvailable == true ? recognizer : nil
    }

    private static func recognize(
        audioData: Data, recognizer: SFSpeechRecognizer, cancellation: HTTPRequestCancellation, timeout: TimeInterval
    ) -> String? {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("cloude-transcribe-\(UUID().uuidString).wav")
        if (try? audioData.write(to: url)) != nil {
            defer { try? FileManager.default.removeItem(at: url) }
            let recognitionRequest = SFSpeechURLRecognitionRequest(url: url)
            recognitionRequest.shouldReportPartialResults = false
            if recognizer.supportsOnDeviceRecognition {
                recognitionRequest.requiresOnDeviceRecognition = true
            }
            let operation = TranscriptionOperation<String>()
            cancellation.observe { operation.finish(nil) }
            defer { cancellation.stopObserving() }
            if !cancellation.isCancelled {
                let task = recognizer.recognitionTask(with: recognitionRequest) { result, error in
                    if let result, result.isFinal { operation.finish(result.bestTranscription.formattedString) }
                    if error != nil { operation.finish(nil) }
                }
                operation.setCancellation { task.cancel() }
            }
            return operation.wait(timeout: timeout)?.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return nil
    }
}

import Foundation
import Speech

@main struct LocalSpeechTests {
    @MainActor static func main() async {
        let recognizer = ChatLocalTranscription()
        let canceledPermission = Task { await recognizer.transcribe(audio: Data([1])) }
        for _ in 0..<10000 where SFSpeechRecognizer.authorizations.isEmpty { await Task.yield() }
        canceledPermission.cancel()
        let permissionResult = await canceledPermission.value
        precondition(permissionResult == nil)
        SFSpeechRecognizer.authorizations[0](.authorized)
        await Task.yield()
        precondition(SFSpeechRecognizer.tasks.isEmpty, "Late authorization cannot start canceled recognition")
        let canceledRecognition = Task { await recognizer.transcribe(audio: Data([2])) }
        for _ in 0..<10000 where SFSpeechRecognizer.authorizations.count < 2 { await Task.yield() }
        SFSpeechRecognizer.authorizations[1](.authorized)
        for _ in 0..<10000 where SFSpeechRecognizer.tasks.isEmpty { await Task.yield() }
        precondition(SFSpeechRecognizer.tasks.count == 1)
        canceledRecognition.cancel()
        let recognitionResult = await canceledRecognition.value
        precondition(recognitionResult == nil && SFSpeechRecognizer.tasks[0].canceled)
        precondition(!FileManager.default.fileExists(atPath: SFSpeechRecognizer.urls[0].path))
        let final = Task { await recognizer.transcribe(audio: Data([3])) }
        for _ in 0..<10000 where SFSpeechRecognizer.authorizations.count < 3 { await Task.yield() }
        SFSpeechRecognizer.authorizations[2](.authorized)
        for _ in 0..<10000 where SFSpeechRecognizer.tasks.count < 2 { await Task.yield() }
        SFSpeechRecognizer.results[0](SFSpeechRecognitionResult("stale canceled text"), nil)
        SFSpeechRecognizer.results[1](SFSpeechRecognitionResult("Accepted text"), nil)
        SFSpeechRecognizer.results[1](nil, NSError(domain: "late error", code: 1))
        let finalResult = await final.value
        precondition(finalResult == "Accepted text" && SFSpeechRecognizer.tasks[1].canceled)
        precondition(!FileManager.default.fileExists(atPath: SFSpeechRecognizer.urls[1].path))
        print(
            "PASS local Speech: cancellation resumes authorization/recognition promptly, native task canceled, temporary audio removed, stale generation and duplicate final/error completions fenced"
        )
    }
}

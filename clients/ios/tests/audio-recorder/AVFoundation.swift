import Foundation

public let AVFormatIDKey = "format"
public let AVSampleRateKey = "sampleRate"
public let AVNumberOfChannelsKey = "channels"
public let AVLinearPCMBitDepthKey = "depth"
public let AVLinearPCMIsFloatKey = "float"
public let AVLinearPCMIsBigEndianKey = "endian"
public let kAudioFormatLinearPCM = 1
@MainActor public enum AVAudioApplication {
    public static var callbacks: [@Sendable (Bool) -> Void] = []
    public static func requestRecordPermission(_ callback: @escaping @Sendable (Bool) -> Void) {
        callbacks.append(callback)
    }
}
@MainActor public final class AVAudioSession {
    public enum Category { case playAndRecord }
    public enum Mode { case `default` }
    private static let shared = AVAudioSession()
    public static func sharedInstance() -> AVAudioSession { shared }
    public func setCategory(_ category: Category, mode: Mode) throws {}
    public func setActive(_ value: Bool) throws {}
}
@MainActor public final class AVAudioRecorder {
    public static var starts = 0
    public var isMeteringEnabled = false
    public init(url: URL, settings: [String: Any]) throws {}
    public func record() -> Bool {
        Self.starts += 1
        return true
    }
    public func stop() {}
    public func updateMeters() {}
    public func averagePower(forChannel: Int) -> Float { -10 }
}

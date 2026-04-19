import Foundation

struct ChatMessage: Codable, Identifiable, Equatable {
    var id: UUID
    var kind: ChatMessageKind
    var text: String
    let timestamp: Date
    var toolCalls: [ToolCall]
    var durationMs: Int?
    var costUsd: Double?
    var imageBase64: String?
    var imageThumbnails: [String]?
    var serverUUID: String?
    var model: String?

    init(
        kind: ChatMessageKind,
        text: String,
        timestamp: Date = Date(),
        toolCalls: [ToolCall] = [],
        durationMs: Int? = nil,
        costUsd: Double? = nil,
        imageBase64: String? = nil,
        imageThumbnails: [String]? = nil,
        serverUUID: String? = nil,
        model: String? = nil
    ) {
        self.id = UUID()
        self.kind = kind
        self.text = text
        self.timestamp = timestamp
        self.toolCalls = toolCalls
        self.durationMs = durationMs
        self.costUsd = costUsd
        self.imageBase64 = imageBase64
        self.imageThumbnails = imageThumbnails
        self.serverUUID = serverUUID
        self.model = model
    }

    var isUser: Bool { kind.isUser }

    var isRecoverableLiveMessage: Bool {
        if case .assistant(let wasInterrupted) = kind {
            if wasInterrupted { return true }
            return serverUUID == nil && durationMs == nil && costUsd == nil
        }
        return false
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        let isUser = try container.decode(Bool.self, forKey: .isUser)
        let isQueued = try container.decodeIfPresent(Bool.self, forKey: .isQueued) ?? false
        let wasInterrupted = try container.decodeIfPresent(Bool.self, forKey: .wasInterrupted) ?? false
        kind = isUser ? .user(isQueued: isQueued) : .assistant(wasInterrupted: wasInterrupted)
        text = try container.decode(String.self, forKey: .text)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        toolCalls = try container.decodeIfPresent([ToolCall].self, forKey: .toolCalls) ?? []
        durationMs = try container.decodeIfPresent(Int.self, forKey: .durationMs)
        costUsd = try container.decodeIfPresent(Double.self, forKey: .costUsd)
        imageBase64 = try container.decodeIfPresent(String.self, forKey: .imageBase64)
        imageThumbnails = try container.decodeIfPresent([String].self, forKey: .imageThumbnails)
        serverUUID = try container.decodeIfPresent(String.self, forKey: .serverUUID)
        model = try container.decodeIfPresent(String.self, forKey: .model)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(text, forKey: .text)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(toolCalls, forKey: .toolCalls)
        try container.encodeIfPresent(durationMs, forKey: .durationMs)
        try container.encodeIfPresent(costUsd, forKey: .costUsd)
        try container.encodeIfPresent(imageBase64, forKey: .imageBase64)
        try container.encodeIfPresent(imageThumbnails, forKey: .imageThumbnails)
        try container.encodeIfPresent(serverUUID, forKey: .serverUUID)
        try container.encodeIfPresent(model, forKey: .model)
        switch kind {
        case .user(let isQueued):
            try container.encode(true, forKey: .isUser)
            try container.encode(isQueued, forKey: .isQueued)
            try container.encode(false, forKey: .wasInterrupted)
        case .assistant(let wasInterrupted):
            try container.encode(false, forKey: .isUser)
            try container.encode(false, forKey: .isQueued)
            try container.encode(wasInterrupted, forKey: .wasInterrupted)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case id, isUser, text, timestamp, toolCalls, durationMs, costUsd, isQueued, wasInterrupted, imageBase64, imageThumbnails, serverUUID, model
    }
}

//
//  Messages.swift
//  Cloude Agent
//
//  Shared protocol messages between iOS client and macOS agent
//

import Foundation
import UniformTypeIdentifiers

// MARK: - Client → Server Messages

enum ClientMessage: Codable {
    case chat(message: String, workingDirectory: String?)
    case abort
    case auth(token: String)
    case listDirectory(path: String)
    case getFile(path: String)

    enum CodingKeys: String, CodingKey {
        case type, message, workingDirectory, token, path
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "chat":
            let message = try container.decode(String.self, forKey: .message)
            let workingDirectory = try container.decodeIfPresent(String.self, forKey: .workingDirectory)
            self = .chat(message: message, workingDirectory: workingDirectory)
        case "abort":
            self = .abort
        case "auth":
            let token = try container.decode(String.self, forKey: .token)
            self = .auth(token: token)
        case "list_directory":
            let path = try container.decode(String.self, forKey: .path)
            self = .listDirectory(path: path)
        case "get_file":
            let path = try container.decode(String.self, forKey: .path)
            self = .getFile(path: path)
        default:
            throw DecodingError.dataCorrupted(.init(codingPath: [CodingKeys.type], debugDescription: "Unknown type: \(type)"))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .chat(let message, let workingDirectory):
            try container.encode("chat", forKey: .type)
            try container.encode(message, forKey: .message)
            try container.encodeIfPresent(workingDirectory, forKey: .workingDirectory)
        case .abort:
            try container.encode("abort", forKey: .type)
        case .auth(let token):
            try container.encode("auth", forKey: .type)
            try container.encode(token, forKey: .token)
        case .listDirectory(let path):
            try container.encode("list_directory", forKey: .type)
            try container.encode(path, forKey: .path)
        case .getFile(let path):
            try container.encode("get_file", forKey: .type)
            try container.encode(path, forKey: .path)
        }
    }
}

// MARK: - Server → Client Messages

enum ServerMessage: Codable {
    case output(text: String)
    case fileChange(path: String, diff: String?, content: String?)
    case image(path: String, base64: String)
    case status(state: AgentState)
    case authRequired
    case authResult(success: Bool, message: String?)
    case error(message: String)
    case directoryListing(path: String, entries: [FileEntry])
    case fileContent(path: String, data: String, mimeType: String, size: Int64)

    enum CodingKeys: String, CodingKey {
        case type, text, path, diff, content, base64, state, success, message, entries, data, mimeType, size
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "output":
            let text = try container.decode(String.self, forKey: .text)
            self = .output(text: text)
        case "file_change":
            let path = try container.decode(String.self, forKey: .path)
            let diff = try container.decodeIfPresent(String.self, forKey: .diff)
            let content = try container.decodeIfPresent(String.self, forKey: .content)
            self = .fileChange(path: path, diff: diff, content: content)
        case "image":
            let path = try container.decode(String.self, forKey: .path)
            let base64 = try container.decode(String.self, forKey: .base64)
            self = .image(path: path, base64: base64)
        case "status":
            let state = try container.decode(AgentState.self, forKey: .state)
            self = .status(state: state)
        case "auth_required":
            self = .authRequired
        case "auth_result":
            let success = try container.decode(Bool.self, forKey: .success)
            let message = try container.decodeIfPresent(String.self, forKey: .message)
            self = .authResult(success: success, message: message)
        case "error":
            let message = try container.decode(String.self, forKey: .message)
            self = .error(message: message)
        case "directory_listing":
            let path = try container.decode(String.self, forKey: .path)
            let entries = try container.decode([FileEntry].self, forKey: .entries)
            self = .directoryListing(path: path, entries: entries)
        case "file_content":
            let path = try container.decode(String.self, forKey: .path)
            let data = try container.decode(String.self, forKey: .data)
            let mimeType = try container.decode(String.self, forKey: .mimeType)
            let size = try container.decode(Int64.self, forKey: .size)
            self = .fileContent(path: path, data: data, mimeType: mimeType, size: size)
        default:
            throw DecodingError.dataCorrupted(.init(codingPath: [CodingKeys.type], debugDescription: "Unknown type: \(type)"))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .output(let text):
            try container.encode("output", forKey: .type)
            try container.encode(text, forKey: .text)
        case .fileChange(let path, let diff, let content):
            try container.encode("file_change", forKey: .type)
            try container.encode(path, forKey: .path)
            try container.encodeIfPresent(diff, forKey: .diff)
            try container.encodeIfPresent(content, forKey: .content)
        case .image(let path, let base64):
            try container.encode("image", forKey: .type)
            try container.encode(path, forKey: .path)
            try container.encode(base64, forKey: .base64)
        case .status(let state):
            try container.encode("status", forKey: .type)
            try container.encode(state, forKey: .state)
        case .authRequired:
            try container.encode("auth_required", forKey: .type)
        case .authResult(let success, let message):
            try container.encode("auth_result", forKey: .type)
            try container.encode(success, forKey: .success)
            try container.encodeIfPresent(message, forKey: .message)
        case .error(let message):
            try container.encode("error", forKey: .type)
            try container.encode(message, forKey: .message)
        case .directoryListing(let path, let entries):
            try container.encode("directory_listing", forKey: .type)
            try container.encode(path, forKey: .path)
            try container.encode(entries, forKey: .entries)
        case .fileContent(let path, let data, let mimeType, let size):
            try container.encode("file_content", forKey: .type)
            try container.encode(path, forKey: .path)
            try container.encode(data, forKey: .data)
            try container.encode(mimeType, forKey: .mimeType)
            try container.encode(size, forKey: .size)
        }
    }
}

enum AgentState: String, Codable {
    case idle
    case running
}

// MARK: - File Entry

struct FileEntry: Codable, Identifiable {
    var id: String { path }
    let name: String
    let path: String
    let isDirectory: Bool
    let size: Int64
    let modified: Date
    let mimeType: String?

    static func from(url: URL) -> FileEntry? {
        let fileManager = FileManager.default
        guard let attrs = try? fileManager.attributesOfItem(atPath: url.path) else {
            return nil
        }

        let isDirectory = (attrs[.type] as? FileAttributeType) == .typeDirectory
        let size = (attrs[.size] as? Int64) ?? 0
        let modified = (attrs[.modificationDate] as? Date) ?? Date()

        var mimeType: String? = nil
        if !isDirectory {
            if let type = UTType(filenameExtension: url.pathExtension) {
                mimeType = type.preferredMIMEType
            }
        }

        return FileEntry(
            name: url.lastPathComponent,
            path: url.path,
            isDirectory: isDirectory,
            size: size,
            modified: modified,
            mimeType: mimeType
        )
    }
}

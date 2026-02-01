//
//  FilePathPreviewView.swift
//  Cloude

import SwiftUI
import CloudeShared

struct FilePathPreviewView: View {
    let path: String
    @ObservedObject var connection: ConnectionManager
    @Environment(\.dismiss) var dismiss

    @State private var isLoading = true
    @State private var fileData: Data?
    @State private var mimeType: String?
    @State private var errorMessage: String?

    private var fileName: String {
        (path as NSString).lastPathComponent
    }

    private var fileExtension: String {
        (path as NSString).pathExtension.lowercased()
    }

    private var isImage: Bool {
        ["png", "jpg", "jpeg", "gif", "webp", "heic", "svg"].contains(fileExtension)
    }

    private var isText: Bool {
        ["txt", "md", "json", "swift", "py", "js", "ts", "html", "css", "yml", "yaml", "sh", "plist", "xml"].contains(fileExtension)
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle(fileName)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark")
                        }
                    }
                }
        }
        .onAppear { loadFile() }
    }

    @ViewBuilder
    private var content: some View {
        if isLoading {
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.2)
                Text("Loading...")
                    .foregroundColor(.secondary)
            }
        } else if let error = errorMessage {
            ContentUnavailableView("Error", systemImage: "exclamationmark.triangle", description: Text(error))
        } else if let data = fileData {
            fileContent(data)
        }
    }

    @ViewBuilder
    private func fileContent(_ data: Data) -> some View {
        if isImage, let image = UIImage(data: data) {
            ScrollView {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .padding()
            }
        } else if isText, let text = String(data: data, encoding: .utf8) {
            ScrollView {
                Text(text)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else {
            VStack(spacing: 16) {
                Image(systemName: "doc")
                    .font(.system(size: 60))
                    .foregroundColor(.secondary)
                Text(fileName)
                    .font(.headline)
                Text("\(data.count.formatted(.byteCount(style: .file)))")
                    .foregroundColor(.secondary)
            }
        }
    }

    private func loadFile() {
        isLoading = true
        connection.getFile(path: path)

        connection.onFileContent = { responsePath, data, mime, _, _ in
            guard responsePath == path else { return }
            isLoading = false
            mimeType = mime

            if let decoded = Data(base64Encoded: data) {
                fileData = decoded
            } else {
                errorMessage = "Failed to decode file"
            }
        }
    }
}

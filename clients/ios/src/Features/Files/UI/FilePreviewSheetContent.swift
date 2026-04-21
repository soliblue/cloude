import SwiftUI

struct FilePreviewSheetContent: View {
    let node: FileNodeDTO
    let type: FilePreviewContentType
    let data: Data
    let wrap: Bool

    var body: some View {
        switch type {
        case .image:
            FilePreviewImage(data: data)
        case .gif:
            FilePreviewGIF(data: data)
        case .video:
            FilePreviewVideo(data: data, fileName: node.name)
        case .audio:
            FilePreviewAudio(data: data)
        case .pdf:
            FilePreviewPDF(data: data)
        case .markdown:
            FilePreviewMarkdown(data: data)
        case .json:
            FilePreviewJSON(data: data)
        case .csv:
            FilePreviewCSV(data: data)
        case .html:
            FilePreviewHTML(data: data)
        case .xml:
            FilePreviewXML(data: data)
        case .code(let language):
            FilePreviewCode(data: data, language: language, wrap: wrap)
        case .text:
            FilePreviewCode(data: data, language: "plaintext", wrap: wrap)
        case .binary:
            FilePreviewBinary(node: node)
        }
    }
}

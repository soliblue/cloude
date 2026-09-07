import SwiftUI

struct FilePreviewSheetContent: View {
    let node: FileNodeDTO
    let type: FilePreviewContentType
    let resource: FilePreviewResource
    let wrap: Bool

    var body: some View {
        if resource.isTruncated {
            if type.isCode || type.hasRenderedView {
                FilePreviewCode(data: resource.data ?? Data(), language: type.sourceLanguage, wrap: wrap)
            } else {
                FilePreviewBinary(node: node)
            }
        } else {
            switch type {
            case .image:
                FilePreviewImage(data: resource.data ?? Data())
            case .gif:
                FilePreviewGIF(data: resource.data ?? Data())
            case .video:
                FilePreviewVideo(url: resource.url)
            case .audio:
                FilePreviewAudio(url: resource.url)
            case .pdf:
                FilePreviewPDF(url: resource.url)
            case .markdown:
                FilePreviewMarkdown(data: resource.data ?? Data())
            case .json:
                FilePreviewJSON(data: resource.data ?? Data())
            case .csv:
                FilePreviewCSV(data: resource.data ?? Data(), tabSeparated: node.name.lowercased().hasSuffix(".tsv"))
            case .html:
                FilePreviewHTML(data: resource.data ?? Data())
            case .xml:
                FilePreviewXML(data: resource.data ?? Data())
            case .code(let language):
                FilePreviewCode(data: resource.data ?? Data(), language: language, wrap: wrap)
            case .text:
                FilePreviewCode(data: resource.data ?? Data(), language: "plaintext", wrap: wrap)
            case .binary:
                FilePreviewBinary(node: node)
            }
        }
    }
}

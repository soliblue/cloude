import Foundation

struct FilePreviewXMLNode {
    let name: String
    let attributes: [String: String]
    var children: [FilePreviewXMLNode]
    var text: String

    static func parse(_ data: Data) -> FilePreviewXMLNode? {
        let builder = FilePreviewXMLNodeBuilder()
        let parser = XMLParser(data: data)
        parser.delegate = builder
        parser.parse()
        return builder.root
    }
}

private final class FilePreviewXMLNodeBuilder: NSObject, XMLParserDelegate {
    var root: FilePreviewXMLNode?
    private var stack: [FilePreviewXMLNode] = []

    func parser(
        _ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?,
        qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]
    ) {
        stack.append(
            FilePreviewXMLNode(
                name: elementName, attributes: attributeDict, children: [], text: ""))
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if !stack.isEmpty {
            stack[stack.count - 1].text += string
        }
    }

    func parser(
        _ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        if var done = stack.popLast() {
            done.text = done.text.trimmingCharacters(in: .whitespacesAndNewlines)
            if stack.isEmpty {
                root = done
            } else {
                stack[stack.count - 1].children.append(done)
            }
        }
    }
}

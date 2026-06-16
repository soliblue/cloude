import XCTest

@testable import Cloude

final class FilePreviewContentTypeTests: XCTestCase {
    func testDetectsKnownExtensionsCaseInsensitively() {
        XCTAssertEqual(FilePreviewContentType.detect(path: "/tmp/IMAGE.PNG"), .image)
        XCTAssertEqual(FilePreviewContentType.detect(path: "/tmp/movie.mov"), .video)
        XCTAssertEqual(FilePreviewContentType.detect(path: "/tmp/report.md"), .markdown)
        XCTAssertEqual(FilePreviewContentType.detect(path: "/tmp/script.swift"), .code(language: "swift"))
    }

    func testSourceLanguageAndRenderedFlagsMatchType() {
        XCTAssertTrue(FilePreviewContentType.markdown.hasRenderedView)
        XCTAssertFalse(FilePreviewContentType.code(language: "swift").hasRenderedView)
        XCTAssertTrue(FilePreviewContentType.text.isCode)
        XCTAssertEqual(FilePreviewContentType.html.sourceLanguage, "xml")
    }

    func testCloudeFileURLRoundTripsPaths() {
        let path = "/Users/soli/projects/cloude/hello world.swift"
        let url = CloudeFileURL.url(for: path)

        XCTAssertEqual(url?.scheme, "cloude")
        XCTAssertEqual(url?.host, "file")
        XCTAssertEqual(url.flatMap(CloudeFileURL.path(from:)), path)
        XCTAssertNil(CloudeFileURL.path(from: URL(string: "https://example.com/file")!))
    }
}

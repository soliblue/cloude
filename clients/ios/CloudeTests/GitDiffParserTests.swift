import XCTest

@testable import Cloude

final class GitDiffParserTests: XCTestCase {
    func testParsesDiffLinesAndCleansHunkLabelsWithAsciiPunctuation() {
        let diff = """
        diff --git a/file.swift b/file.swift
        index 1111111..2222222 100644
        --- a/file.swift
        +++ b/file.swift
        @@ -1,2 +1,2 @@ func run
        -old
        +new
         same
        Binary files a/image.png and b/image.png differ
        """

        let lines = GitDiffParser.parse(diff)

        XCTAssertEqual(lines.map(\.kind), [.hunk, .removed, .added, .context, .binary])
        XCTAssertEqual(lines.map(\.text), [
            "func run - Line 1",
            "old",
            "new",
            "same",
            "Binary files a/image.png and b/image.png differ",
        ])
    }
}

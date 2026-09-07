import Foundation

@main
struct GitDiffParserTests {
    static func main() {
        let diff = """
            diff --git a/counter.swift b/counter.swift
            index 1111111..2222222 100644
            --- a/counter.swift
            +++ b/counter.swift
            @@ -4,3 +4,3 @@ counter
            ---counter
            +++counter
            -old
            \\ No newline at end of file
            +new
             context

            """
        let lines = GitDiffParser.parse(diff)
        precondition(lines.filter { $0.kind == .removed }.map(\.text) == ["--counter", "old"])
        precondition(lines.filter { $0.kind == .added }.map(\.text) == ["++counter", "new"])
        precondition(lines.filter { $0.kind == .removed }.compactMap(\.oldLine) == [4, 5])
        precondition(lines.filter { $0.kind == .added }.compactMap(\.newLine) == [4, 5])
        precondition(lines.last?.oldLine == 6 && lines.last?.newLine == 6 && lines.last?.text == "context")
        precondition(lines.first?.text == "counter: Line 4")
        precondition(GitDiffParser.groupHunks(lines, filePath: "counter.swift").first?.additions == 2)
        let second = "\ndiff --git a/a b/a\n--- a/a\n+++ b/a\n@@ -1 +9 @@\n-old\n+new\n"
        let merged = GitDiffParser.parse(diff + second)
        precondition(merged.filter { $0.kind == .added }.last?.newLine == 9)
        precondition(GitDiffParser.parse("Binary files a/a and b/a differ\n").count == 1)
        precondition(GitDiffParser.parse("").isEmpty)
        print(
            "Git diff parsing: literal plus/minus prefixes, line numbers, missing newline, file boundaries and binary diff passed"
        )
    }
}

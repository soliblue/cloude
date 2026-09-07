import Foundation

@main
struct FileCSVTests {
    static func check(_ condition: Bool) { precondition(condition) }

    static func main() async {
        check(await FileCSVService.rows(Data("name,note\r\n\"日本語\",\"say \"\"hello\"\"\"\r\n".utf8)) == [["name", "note"], ["日本語", "say \"hello\""]])
        check(await FileCSVService.rows(Data("a,\"two\nlines\",\n".utf8)) == [["a", "two\nlines", ""]])
        check(await FileCSVService.rows(Data("x\ty, z\n".utf8), tabSeparated: true) == [["x", "y, z"]])
        check(await FileCSVService.rows(Data([0xEF, 0xBB, 0xBF] + Array("name,value\rtest,1".utf8))) == [["name", "value"], ["test", "1"]])
        check(await FileCSVService.rows(Data("\"\"".utf8)) == [[""]])
        check(await FileCSVService.rows(Data()) == [])
        check(await FileCSVService.rows(Data(",,".utf8)) == [["", "", ""]])
        print("PASS: CSV escaped quotes, multiline fields, Unicode, explicit TSV, BOM, CRLF and empty fields")
    }
}

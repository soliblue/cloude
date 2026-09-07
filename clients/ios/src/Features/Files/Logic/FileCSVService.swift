import Foundation

enum FileCSVService {
    @concurrent
    static func rows(_ data: Data, tabSeparated: Bool = false) async -> [[String]] {
        let bytes = Array(data)
        var rows: [[String]] = []
        var row: [String] = []
        var field: [UInt8] = []
        var quoted = false
        var index = bytes.starts(with: [0xEF, 0xBB, 0xBF]) ? 3 : 0
        while index < bytes.count {
            let byte = bytes[index]
            if byte == 34 {
                if quoted && index + 1 < bytes.count && bytes[index + 1] == 34 {
                    field.append(34)
                    index += 1
                } else {
                    quoted.toggle()
                }
            } else if !quoted && byte == (tabSeparated ? 9 : 44) {
                row.append(String(decoding: field, as: UTF8.self))
                field.removeAll(keepingCapacity: true)
            } else if !quoted && (byte == 10 || byte == 13) {
                row.append(String(decoding: field, as: UTF8.self))
                rows.append(row)
                row.removeAll(keepingCapacity: true)
                field.removeAll(keepingCapacity: true)
                if byte == 13 && index + 1 < bytes.count && bytes[index + 1] == 10 { index += 1 }
            } else {
                field.append(byte)
            }
            index += 1
        }
        if !field.isEmpty || !row.isEmpty || bytes.last == 34 {
            row.append(String(decoding: field, as: UTF8.self))
            rows.append(row)
        }
        return rows
    }
}

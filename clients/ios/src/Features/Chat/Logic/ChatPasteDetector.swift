import Foundation

enum ChatPasteDetector {
    static let threshold = 1000

    static func extract(old: String, new: String) -> (text: String, remaining: String)? {
        if new.count - old.count >= threshold {
            let oldChars = Array(old)
            let newChars = Array(new)
            var prefix = 0
            while prefix < oldChars.count && prefix < newChars.count
                && oldChars[prefix] == newChars[prefix]
            {
                prefix += 1
            }
            var suffix = 0
            while suffix < oldChars.count - prefix && suffix < newChars.count - prefix
                && oldChars[oldChars.count - 1 - suffix] == newChars[newChars.count - 1 - suffix]
            {
                suffix += 1
            }
            let text = String(newChars[prefix..<(newChars.count - suffix)])
            if text.count >= threshold {
                let remaining =
                    String(oldChars[..<prefix]) + String(oldChars[(oldChars.count - suffix)...])
                return (text, remaining)
            }
        }
        return nil
    }
}

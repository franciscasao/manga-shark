import Foundation

extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }

    func truncated(to length: Int, trailing: String = "...") -> String {
        if self.count <= length {
            return self
        }
        return String(self.prefix(length)) + trailing
    }

    var htmlStripped: String {
        // Use regex to strip HTML tags - simpler approach that doesn't require UIKit
        guard let regex = try? NSRegularExpression(pattern: "<[^>]+>", options: .caseInsensitive) else {
            return self
        }

        let range = NSRange(self.startIndex..., in: self)
        var result = regex.stringByReplacingMatches(in: self, options: [], range: range, withTemplate: "")

        // Decode common HTML entities
        let entities: [(String, String)] = [
            ("&amp;", "&"),
            ("&lt;", "<"),
            ("&gt;", ">"),
            ("&quot;", "\""),
            ("&apos;", "'"),
            ("&#39;", "'"),
            ("&nbsp;", " "),
            ("&ndash;", "–"),
            ("&mdash;", "—"),
            ("&hellip;", "…"),
            ("<br>", "\n"),
            ("<br/>", "\n"),
            ("<br />", "\n")
        ]

        for (entity, replacement) in entities {
            result = result.replacingOccurrences(of: entity, with: replacement)
        }

        // Clean up excessive whitespace
        result = result.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

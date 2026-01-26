import Foundation

enum Formatters {
    static let byteCountFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter
    }()

    static func formatBytes(_ bytes: Int64) -> String {
        byteCountFormatter.string(fromByteCount: bytes)
    }

    static let chapterNumberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        return formatter
    }()

    static func formatChapterNumber(_ number: Double) -> String {
        if number == floor(number) {
            return String(Int(number))
        }
        return chapterNumberFormatter.string(from: NSNumber(value: number)) ?? String(number)
    }
}

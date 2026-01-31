import Foundation

final class ManhwaProgressManager {
    static let shared = ManhwaProgressManager()

    private let userDefaults = UserDefaults.standard
    private let keyPrefix = "manhwa_scroll_offset_"

    private init() {}

    func saveScrollOffset(_ offset: CGFloat, forChapterId chapterId: Int) {
        let key = keyPrefix + String(chapterId)
        userDefaults.set(Double(offset), forKey: key)
    }

    func loadScrollOffset(forChapterId chapterId: Int) -> CGFloat? {
        let key = keyPrefix + String(chapterId)
        let value = userDefaults.double(forKey: key)
        return value > 0 ? CGFloat(value) : nil
    }

    func clearScrollOffset(forChapterId chapterId: Int) {
        let key = keyPrefix + String(chapterId)
        userDefaults.removeObject(forKey: key)
    }

    func saveScrollPercentage(_ percentage: CGFloat, forChapterId chapterId: Int) {
        let key = keyPrefix + "percentage_" + String(chapterId)
        userDefaults.set(Double(percentage), forKey: key)
    }

    func loadScrollPercentage(forChapterId chapterId: Int) -> CGFloat? {
        let key = keyPrefix + "percentage_" + String(chapterId)
        let value = userDefaults.double(forKey: key)
        return value > 0 ? CGFloat(value) : nil
    }
}

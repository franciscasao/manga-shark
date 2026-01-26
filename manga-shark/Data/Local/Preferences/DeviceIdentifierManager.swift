import Foundation

@MainActor
final class DeviceIdentifierManager {
    static let shared = DeviceIdentifierManager()

    let deviceId: String

    private init() {
        // Try loading from UserDefaults
        if let storedId = UserDefaults.standard.string(forKey: UserDefaultsKeys.deviceId) {
            self.deviceId = storedId
        }
        // Generate new UUID if not found
        else {
            let newId = UUID().uuidString
            self.deviceId = newId
            UserDefaults.standard.set(newId, forKey: UserDefaultsKeys.deviceId)
        }
    }
}

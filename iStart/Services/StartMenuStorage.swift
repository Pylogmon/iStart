import Foundation

struct StartMenuStorage {
    private let defaults: UserDefaults

    private enum Keys {
        static let pinnedApplicationIDs = "pinnedApplicationIDs"
        static let recentApplicationIDs = "recentApplicationIDs"
        static let hotKey = "hotKey"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func loadPinnedIDs() -> [String] {
        defaults.stringArray(forKey: Keys.pinnedApplicationIDs) ?? []
    }

    func savePinnedIDs(_ ids: [String]) {
        defaults.set(ids, forKey: Keys.pinnedApplicationIDs)
    }

    func loadRecentIDs() -> [String] {
        defaults.stringArray(forKey: Keys.recentApplicationIDs) ?? []
    }

    func saveRecentIDs(_ ids: [String]) {
        defaults.set(Array(ids.prefix(8)), forKey: Keys.recentApplicationIDs)
    }

    func loadHotKey() -> HotKey {
        HotKey.fromRawValue(defaults.string(forKey: Keys.hotKey) ?? HotKey.commandSpace.rawValue)
    }

    func saveHotKey(_ hotKey: HotKey) {
        defaults.set(hotKey.rawValue, forKey: Keys.hotKey)
    }
}

import Foundation

struct StartMenuStorage {
    private let defaults: UserDefaults

    private enum Keys {
        static let pinnedApplicationIDs = "pinnedApplicationIDs"
        static let recentApplicationIDs = "recentApplicationIDs"
        static let hotKey = "hotKey"
        static let showsRecommendedSection = "showsRecommendedSection"
        static let restoresStartMenuState = "restoresStartMenuState"
        static let showsSettingsWindowOnLaunch = "showsSettingsWindowOnLaunch"
        static let applicationSearchDirectoryBookmarks = "applicationSearchDirectoryBookmarks"
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

    func loadShowsRecommendedSection() -> Bool {
        guard defaults.object(forKey: Keys.showsRecommendedSection) != nil else {
            return true
        }

        return defaults.bool(forKey: Keys.showsRecommendedSection)
    }

    func saveShowsRecommendedSection(_ showsRecommendedSection: Bool) {
        defaults.set(showsRecommendedSection, forKey: Keys.showsRecommendedSection)
    }

    func loadRestoresStartMenuState() -> Bool {
        guard defaults.object(forKey: Keys.restoresStartMenuState) != nil else {
            return true
        }

        return defaults.bool(forKey: Keys.restoresStartMenuState)
    }

    func saveRestoresStartMenuState(_ restoresStartMenuState: Bool) {
        defaults.set(restoresStartMenuState, forKey: Keys.restoresStartMenuState)
    }

    func loadShowsSettingsWindowOnLaunch() -> Bool {
        guard defaults.object(forKey: Keys.showsSettingsWindowOnLaunch) != nil else {
            return true
        }

        return defaults.bool(forKey: Keys.showsSettingsWindowOnLaunch)
    }

    func saveShowsSettingsWindowOnLaunch(_ showsSettingsWindowOnLaunch: Bool) {
        defaults.set(showsSettingsWindowOnLaunch, forKey: Keys.showsSettingsWindowOnLaunch)
    }

    func loadHotKey() -> HotKey {
        if let data = defaults.data(forKey: Keys.hotKey),
           let hotKey = try? JSONDecoder().decode(HotKey.self, from: data) {
            return hotKey
        }

        return HotKey.fromRawValue(defaults.string(forKey: Keys.hotKey) ?? HotKey.commandSpace.rawValue)
    }

    func saveHotKey(_ hotKey: HotKey) {
        if let data = try? JSONEncoder().encode(hotKey) {
            defaults.set(data, forKey: Keys.hotKey)
        }
    }

    func loadApplicationSearchDirectoryBookmarks() -> [Data] {
        defaults.array(forKey: Keys.applicationSearchDirectoryBookmarks) as? [Data] ?? []
    }

    func saveApplicationSearchDirectoryBookmarks(_ bookmarks: [Data]) {
        defaults.set(bookmarks, forKey: Keys.applicationSearchDirectoryBookmarks)
    }
}

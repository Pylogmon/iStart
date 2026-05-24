import Defaults
import Foundation

extension Defaults.Keys {
    static let pinnedApplicationIDs = Key<[String]>("pinnedApplicationIDs", default: [])
    static let recentApplicationIDs = Key<[String]>("recentApplicationIDs", default: [])
    static let hotKey = Key<HotKey>("hotKey", default: .commandSpace)
    static let showsMenuBarExtra = Key<Bool>("showsMenuBarExtra", default: true)
    static let showsRecommendedSection = Key<Bool>("showsRecommendedSection", default: true)
    static let showSettingsAtLaunch = Key<Bool>("showSettingsAtLaunch", default: true)
    static let restoresStartMenuState = Key<Bool>("restoresStartMenuState", default: true)
    static let dockIconClickBehavior = Key<DockIconClickBehavior>("dockIconClickBehavior", default: .openSettings)
    static let recentApplicationLimit = Key<Int>("recentApplicationLimit", default: Defaults.defaultRecentApplicationLimit)
    static let applicationSearchDirectoryBookmarks = Key<[Data]>("applicationSearchDirectoryBookmarks", default: [])
}

extension Defaults {
    static let defaultRecentApplicationLimit = 8
    static let recentApplicationLimitRange = 0...50

    static func clampedRecentApplicationLimit(_ limit: Int) -> Int {
        min(max(limit, recentApplicationLimitRange.lowerBound), recentApplicationLimitRange.upperBound)
    }

    static func loadHotKey(from defaults: UserDefaults = .standard) -> HotKey {
        if let data = defaults.data(forKey: Defaults.Keys.hotKey.name),
           let hotKey = try? JSONDecoder().decode(HotKey.self, from: data) {
            return hotKey
        }

        if let rawValue = defaults.string(forKey: Defaults.Keys.hotKey.name),
           let hotKey = HotKey.all.first(where: { $0.rawValue == rawValue }) {
            defaults[.hotKey] = hotKey
            return hotKey
        }

        return defaults[.hotKey]
    }
}

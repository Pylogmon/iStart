import Defaults
import Foundation

extension Defaults.Keys {
    static let pinnedApplicationIDs = Key<[String]>("pinnedApplicationIDs", default: [])
    static let recentApplicationIDs = Key<[String]>("recentApplicationIDs", default: [])
    static let hotKey = Key<HotKey>("hotKey", default: .optionSpace)
    static let showsMenuBarExtra = Key<Bool>("showsMenuBarExtra", default: true)
    static let showsRecommendedSection = Key<Bool>("showsRecommendedSection", default: true)
    static let showSettingsAtLaunch = Key<Bool>("showSettingsAtLaunch", default: true)
    static let restoresStartMenuState = Key<Bool>("restoresStartMenuState", default: true)
    static let dockIconClickBehavior = Key<DockIconClickBehavior>("dockIconClickBehavior", default: .openSettings)
    static let pinnedApplicationRowCount = Key<Int>("pinnedApplicationRowCount", default: Defaults.defaultPinnedApplicationRowCount)
    static let defaultAllAppsDisplayMode = Key<AllAppsDisplayMode>("defaultAllAppsDisplayMode", default: .categories)
    static let recentApplicationLimit = Key<Int>("recentApplicationLimit", default: Defaults.defaultRecentApplicationLimit)
    static let applicationSearchDirectoryBookmarks = Key<[Data]>("applicationSearchDirectoryBookmarks", default: [])
}

extension Defaults {
    static let defaultPinnedApplicationRowCount = 2
    static let pinnedApplicationRowCountRange = 1...6
    static let defaultRecentApplicationLimit = 8
    static let recentApplicationLimitRange = 0...50

    static func clampedPinnedApplicationRowCount(_ rowCount: Int) -> Int {
        min(max(rowCount, pinnedApplicationRowCountRange.lowerBound), pinnedApplicationRowCountRange.upperBound)
    }

    static func clampedRecentApplicationLimit(_ limit: Int) -> Int {
        min(max(limit, recentApplicationLimitRange.lowerBound), recentApplicationLimitRange.upperBound)
    }

    static func loadHotKey(from defaults: UserDefaults = .standard) -> HotKey {
        if let data = defaults.data(forKey: Defaults.Keys.hotKey.name),
           let decodedHotKey = try? JSONDecoder().decode(HotKey.self, from: data),
           let hotKey = HotKey.all.first(where: { $0.rawValue == decodedHotKey.rawValue }) {
            return hotKey
        }

        if let rawValue = defaults.string(forKey: Defaults.Keys.hotKey.name),
           let hotKey = HotKey.all.first(where: { $0.rawValue == rawValue }) {
            storeHotKey(hotKey, in: defaults)
            return hotKey
        }

        storeHotKey(.optionSpace, in: defaults)
        return .optionSpace
    }

    private static func storeHotKey(_ hotKey: HotKey, in defaults: UserDefaults) {
        if let data = try? JSONEncoder().encode(hotKey) {
            defaults.set(data, forKey: Defaults.Keys.hotKey.name)
        }
    }
}

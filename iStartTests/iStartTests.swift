import Defaults
import Foundation
import Testing
@testable import iStart

struct iStartTests {
    @MainActor
    @Test func scannerFindsApplicationsAndSortsByName() throws {
        let root = try temporaryDirectory()
        try makeApp(named: "Notes", bundleIdentifier: "com.example.notes", in: root)
        try makeApp(named: "Calendar", bundleIdentifier: "com.example.calendar", in: root)

        let scanner = ApplicationScanner(searchRoots: [root])
        let apps = scanner.scan()

        #expect(apps.map(\.name) == ["Calendar", "Notes"])
        #expect(apps.map(\.bundleIdentifier) == ["com.example.calendar", "com.example.notes"])
    }

    @MainActor
    @Test func scannerDoesNotExposeAppExtensionAsDisplayName() throws {
        let root = try temporaryDirectory()
        let appURL = root.appendingPathComponent("Plain.app", isDirectory: true)
        try FileManager.default.createDirectory(at: appURL, withIntermediateDirectories: true)

        let scanner = ApplicationScanner(searchRoots: [root])
        let apps = scanner.scan()

        #expect(apps.map(\.name) == ["Plain"])
    }

    @MainActor
    @Test func scannerFindsChromePWAApplicationsInNestedUserApplicationsFolder() throws {
        let root = try temporaryDirectory()
        let chromeApps = root
            .appendingPathComponent("Applications", isDirectory: true)
            .appendingPathComponent("Chrome Apps.localized", isDirectory: true)
        try makeApp(
            named: "Photo Border",
            bundleIdentifier: "com.google.Chrome.app.oighanpbhfmkphmfibgddmaniojoaelb",
            in: chromeApps,
            includesDisplayName: false,
            extraInfo: ["CrAppModeShortcutName": "浮光水印"]
        )

        let scanner = ApplicationScanner(searchRoots: [root.appendingPathComponent("Applications", isDirectory: true)])
        let apps = scanner.scan()

        #expect(apps.map(\.name) == ["浮光水印"])
        #expect(apps.map(\.bundleIdentifier) == ["com.google.Chrome.app.oighanpbhfmkphmfibgddmaniojoaelb"])
    }

    @MainActor
    @Test func scannerFindsTopLevelApplicationSymlinks() throws {
        let root = try temporaryDirectory()
        let systemApplications = root.appendingPathComponent("SystemApplications", isDirectory: true)
        try makeApp(named: "Safari", bundleIdentifier: "com.apple.Safari", in: systemApplications)
        var safariSymlink = root.appendingPathComponent("Safari.app", isDirectory: true)
        try FileManager.default.createSymbolicLink(
            at: safariSymlink,
            withDestinationURL: systemApplications.appendingPathComponent("Safari.app", isDirectory: true)
        )
        var resourceValues = URLResourceValues()
        resourceValues.isHidden = true
        try safariSymlink.setResourceValues(resourceValues)

        let scanner = ApplicationScanner(searchRoots: [root])
        let apps = scanner.scan()
        print(apps)
        #expect(apps.map(\.name) == ["Safari"])
        #expect(apps.map(\.bundleIdentifier) == ["com.apple.Safari"])
    }

    @MainActor
    @Test func scannerPrefersLocalizedChineseApplicationDisplayName() throws {
        let root = try temporaryDirectory()
        try makeApp(
            named: "WeChat",
            bundleIdentifier: "com.tencent.xinWeChat",
            in: root,
            localizedInfo: [
                "zh-Hans": [
                    "CFBundleDisplayName": "微信"
                ]
            ]
        )

        let scanner = ApplicationScanner(searchRoots: [root])
        let apps = scanner.scan()

        #expect(apps.map(\.name) == ["微信"])
    }

    @MainActor
    @Test func modelFiltersByNameAndBundleIdentifier() throws {
        let root = try temporaryDirectory()
        try makeApp(named: "Pixelmator Pro", bundleIdentifier: "com.pixelmatorteam.pixelmator.x", in: root)
        try makeApp(named: "Terminal", bundleIdentifier: "com.apple.Terminal", in: root)

        let model = StartMenuModel(scanner: ApplicationScanner(searchRoots: [root]), defaults: isolatedDefaults())
        model.reloadApplications()

        model.searchText = "pixel"
        #expect(model.filteredApplications.map(\.name) == ["Pixelmator Pro"])

        model.searchText = "apple.Terminal"
        #expect(model.filteredApplications.map(\.name) == ["Terminal"])
    }

    @MainActor
    @Test func modelFiltersChineseApplicationNamesByPinyin() throws {
        let root = try temporaryDirectory()
        try makeApp(named: "微信", bundleIdentifier: "com.tencent.xinWeChat", in: root)
        try makeApp(named: "备忘录", bundleIdentifier: "com.apple.Notes", in: root)

        let model = StartMenuModel(scanner: ApplicationScanner(searchRoots: [root]), defaults: isolatedDefaults())
        model.reloadApplications()

        model.searchText = "weixin"
        #expect(model.filteredApplications.map(\.name) == ["微信"])

        model.searchText = "wx"
        #expect(model.filteredApplications.map(\.name) == ["微信"])
    }

    @MainActor
    @Test func modelFiltersApplicationNamesByFuzzyInitials() throws {
        let root = try temporaryDirectory()
        try makeApp(named: "Visual Studio Code", bundleIdentifier: "com.microsoft.VSCode", in: root)
        try makeApp(named: "Calendar", bundleIdentifier: "com.example.calendar", in: root)

        let model = StartMenuModel(scanner: ApplicationScanner(searchRoots: [root]), defaults: isolatedDefaults())
        model.reloadApplications()

        model.searchText = "vsc"
        #expect(model.filteredApplications.map(\.name) == ["Visual Studio Code"])
    }

    @MainActor
    @Test func modelSortsSearchResultsByMatchRelevance() throws {
        let root = try temporaryDirectory()
        try makeApp(named: "Keynote", bundleIdentifier: "com.apple.Keynote", in: root)
        try makeApp(named: "My Notes", bundleIdentifier: "com.example.notes-helper", in: root)
        try makeApp(named: "Notes", bundleIdentifier: "com.apple.Notes", in: root)

        let model = StartMenuModel(scanner: ApplicationScanner(searchRoots: [root]), defaults: isolatedDefaults())
        model.reloadApplications()

        model.searchText = "note"

        #expect(model.filteredApplications.map(\.name) == ["Notes", "My Notes", "Keynote"])
    }

    @MainActor
    @Test func pinnedAppsPersistInOrder() throws {
        let root = try temporaryDirectory()
        try makeApp(named: "Alpha", bundleIdentifier: "com.example.alpha", in: root)
        try makeApp(named: "Beta", bundleIdentifier: "com.example.beta", in: root)
        let defaults = isolatedDefaults()

        let model = StartMenuModel(scanner: ApplicationScanner(searchRoots: [root]), defaults: defaults)
        model.reloadApplications()

        let alpha = try #require(model.applications.first { $0.name == "Alpha" })
        let beta = try #require(model.applications.first { $0.name == "Beta" })
        model.togglePinned(beta)
        model.togglePinned(alpha)

        let reloaded = StartMenuModel(scanner: ApplicationScanner(searchRoots: [root]), defaults: defaults)
        reloaded.reloadApplications()

        #expect(reloaded.pinnedApplications.map(\.name) == ["Beta", "Alpha"])
    }

    @MainActor
    @Test func hotKeyDataLoads() throws {
        let defaults = isolatedDefaults()
        let data = try JSONEncoder().encode(HotKey.optionSpace)
        defaults.set(data, forKey: Defaults.Keys.hotKey.name)

        #expect(Defaults.loadHotKey(from: defaults) == .optionSpace)
    }

    @MainActor
    @Test func persistedHotKeyLoadsFromDefaultsStorage() {
        let defaults = isolatedDefaults()
        defaults[.hotKey] = .commandSpace

        #expect(Defaults.loadHotKey(from: defaults) == .commandSpace)
    }

    @MainActor
    @Test func unsupportedHotKeyFallsBackToDefault() throws {
        let defaults = isolatedDefaults()
        let hotKey = HotKey(
            rawValue: "recorded:35:768:p",
            title: "Command Shift P",
            keyCode: 35,
            carbonModifiers: 768
        )

        let data = try JSONEncoder().encode(hotKey)
        defaults.set(data, forKey: Defaults.Keys.hotKey.name)

        #expect(Defaults.loadHotKey(from: defaults) == .optionSpace)
    }

    @MainActor
    @Test func legacyHotKeyRawValueLoads() {
        let suiteName = "iStartTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defaults.set(HotKey.optionSpace.rawValue, forKey: "hotKey")

        #expect(Defaults.loadHotKey(from: defaults) == .optionSpace)
    }

    @MainActor
    @Test func startMenuStateRestoreDefaultsToEnabled() {
        let defaults = isolatedDefaults()

        #expect(defaults[.restoresStartMenuState])
    }

    @MainActor
    @Test func dockIconClickBehaviorDefaultsToOpenSettings() {
        let defaults = isolatedDefaults()

        #expect(defaults[.dockIconClickBehavior] == .openSettings)
    }

    @MainActor
    @Test func dockIconClickBehaviorPersistsSelectedValue() {
        let defaults = isolatedDefaults()
        defaults[.dockIconClickBehavior] = .toggleStartMenu

        #expect(defaults[.dockIconClickBehavior] == .toggleStartMenu)
    }

    @MainActor
    @Test func pinnedApplicationRowCountDefaultsToTwoRows() {
        let defaults = isolatedDefaults()

        #expect(defaults[.pinnedApplicationRowCount] == 2)
    }

    @MainActor
    @Test func modelClampsAndPersistsPinnedApplicationRowCount() {
        let defaults = isolatedDefaults()
        let model = StartMenuModel(defaults: defaults)

        model.setPinnedApplicationRowCount(99)

        #expect(model.pinnedApplicationRowCount == Defaults.pinnedApplicationRowCountRange.upperBound)
        #expect(defaults[.pinnedApplicationRowCount] == Defaults.pinnedApplicationRowCountRange.upperBound)
    }

    @MainActor
    @Test func recommendedApplicationRowCountDefaultsToOneRow() {
        let defaults = isolatedDefaults()

        #expect(defaults[.recommendedApplicationRowCount] == 1)
    }

    @MainActor
    @Test func modelClampsAndPersistsRecommendedApplicationRowCount() {
        let defaults = isolatedDefaults()
        let model = StartMenuModel(defaults: defaults)

        model.setRecommendedApplicationRowCount(99)

        #expect(model.recommendedApplicationRowCount == Defaults.recommendedApplicationRowCountRange.upperBound)
        #expect(defaults[.recommendedApplicationRowCount] == Defaults.recommendedApplicationRowCountRange.upperBound)
    }

    @MainActor
    @Test func defaultAllAppsDisplayModeDefaultsToCategories() {
        let defaults = isolatedDefaults()

        #expect(defaults[.defaultAllAppsDisplayMode] == .categories)
    }

    @MainActor
    @Test func defaultAllAppsDisplayModePersistsSelectedValue() {
        let defaults = isolatedDefaults()
        let model = StartMenuModel(defaults: defaults)

        model.defaultAllAppsDisplayMode = .list

        #expect(defaults[.defaultAllAppsDisplayMode] == .list)
    }

    @MainActor
    @Test func menuBarExtraDefaultsToShown() {
        let defaults = isolatedDefaults()

        #expect(defaults[.showsMenuBarExtra])
    }

    @MainActor
    @Test func menuBarExtraPersistsSelectedValue() {
        let defaults = isolatedDefaults()
        defaults[.showsMenuBarExtra] = false

        #expect(!defaults[.showsMenuBarExtra])
    }

    @MainActor
    @Test func presentationPreparationResetsSearchWhenStateRestoreIsDisabled() {
        let defaults = isolatedDefaults()
        defaults[.restoresStartMenuState] = false
        let model = StartMenuModel(defaults: defaults)
        model.searchText = "terminal"
        let originalHomeResetToken = model.homeResetToken

        model.prepareForPresentation()

        #expect(model.searchText.isEmpty)
        #expect(model.homeResetToken != originalHomeResetToken)
    }

    @MainActor
    @Test func resetPinnedApplicationsUsesInjectedStorage() {
        let defaults = isolatedDefaults()
        defaults[.pinnedApplicationIDs] = ["alpha", "beta"]
        let model = StartMenuModel(defaults: defaults)

        model.resetPinnedApplications()

        #expect(model.pinnedApplicationIDs.isEmpty)
        #expect(defaults[.pinnedApplicationIDs].isEmpty)
    }

    private func makeApp(
        named name: String,
        bundleIdentifier: String,
        in root: URL,
        includesDisplayName: Bool = true,
        extraInfo: [String: Any] = [:],
        localizedInfo: [String: [String: String]] = [:]
    ) throws {
        let appURL = root.appendingPathComponent("\(name).app", isDirectory: true)
        let contentsURL = appURL.appendingPathComponent("Contents", isDirectory: true)
        try FileManager.default.createDirectory(at: contentsURL, withIntermediateDirectories: true)

        var info: [String: Any] = [
            "CFBundleIdentifier": bundleIdentifier,
            "CFBundleName": name,
            "CFBundlePackageType": "APPL"
        ]
        if includesDisplayName {
            info["CFBundleDisplayName"] = name
        }
        info.merge(extraInfo) { _, new in new }

        _ = (info as NSDictionary).write(to: contentsURL.appendingPathComponent("Info.plist"), atomically: true)

        let resourcesURL = contentsURL.appendingPathComponent("Resources", isDirectory: true)
        for (localization, strings) in localizedInfo {
            let localizationURL = resourcesURL.appendingPathComponent("\(localization).lproj", isDirectory: true)
            try FileManager.default.createDirectory(at: localizationURL, withIntermediateDirectories: true)
            _ = (strings as NSDictionary).write(
                to: localizationURL.appendingPathComponent("InfoPlist.strings"),
                atomically: true
            )
        }
    }

    private func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("iStartTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func isolatedDefaults() -> UserDefaults {
        let suiteName = "iStartTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}

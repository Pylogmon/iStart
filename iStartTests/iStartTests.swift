import Carbon.HIToolbox
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

        let model = StartMenuModel(scanner: ApplicationScanner(searchRoots: [root]), storage: isolatedStorage())
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

        let model = StartMenuModel(scanner: ApplicationScanner(searchRoots: [root]), storage: isolatedStorage())
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

        let model = StartMenuModel(scanner: ApplicationScanner(searchRoots: [root]), storage: isolatedStorage())
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

        let model = StartMenuModel(scanner: ApplicationScanner(searchRoots: [root]), storage: isolatedStorage())
        model.reloadApplications()

        model.searchText = "note"

        #expect(model.filteredApplications.map(\.name) == ["Notes", "My Notes", "Keynote"])
    }

    @MainActor
    @Test func pinnedAppsPersistInOrder() throws {
        let root = try temporaryDirectory()
        try makeApp(named: "Alpha", bundleIdentifier: "com.example.alpha", in: root)
        try makeApp(named: "Beta", bundleIdentifier: "com.example.beta", in: root)
        let storage = isolatedStorage()

        let model = StartMenuModel(scanner: ApplicationScanner(searchRoots: [root]), storage: storage)
        model.reloadApplications()

        let alpha = try #require(model.applications.first { $0.name == "Alpha" })
        let beta = try #require(model.applications.first { $0.name == "Beta" })
        model.togglePinned(beta)
        model.togglePinned(alpha)

        let reloaded = StartMenuModel(scanner: ApplicationScanner(searchRoots: [root]), storage: storage)
        reloaded.reloadApplications()

        #expect(reloaded.pinnedApplications.map(\.name) == ["Beta", "Alpha"])
    }

    @MainActor
    @Test func hotKeyPersists() {
        let storage = isolatedStorage()
        storage.saveHotKey(.commandOptionSpace)

        #expect(storage.loadHotKey() == .commandOptionSpace)
    }

    @MainActor
    @Test func customHotKeyPersists() {
        let storage = isolatedStorage()
        let hotKey = HotKey.recorded(keyCode: 35, carbonModifiers: cmdKey | shiftKey, keyEquivalent: "p")

        storage.saveHotKey(hotKey)

        #expect(storage.loadHotKey() == hotKey)
    }

    @MainActor
    @Test func legacyHotKeyRawValueLoads() {
        let suiteName = "iStartTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defaults.set(HotKey.optionSpace.rawValue, forKey: "hotKey")

        let storage = StartMenuStorage(defaults: defaults)

        #expect(storage.loadHotKey() == .optionSpace)
    }

    @MainActor
    @Test func startMenuStateRestoreDefaultsToEnabled() {
        let storage = isolatedStorage()

        #expect(storage.loadRestoresStartMenuState())
    }

    @MainActor
    @Test func settingsWindowLaunchDefaultsToEnabled() {
        let storage = isolatedStorage()

        #expect(storage.loadShowsSettingsWindowOnLaunch())
    }

    @MainActor
    @Test func recentItemsSourceDefaultsToSystem() {
        let storage = isolatedStorage()

        #expect(storage.loadRecentItemsSource() == .system)
    }

    @MainActor
    @Test func recentItemsSourcePersists() {
        let storage = isolatedStorage()

        storage.saveRecentItemsSource(.application)

        #expect(storage.loadRecentItemsSource() == .application)
    }

    @MainActor
    @Test func modelUsesApplicationRecentItemsWhenSelected() throws {
        let root = try temporaryDirectory()
        try makeApp(named: "Alpha", bundleIdentifier: "com.example.alpha", in: root)
        try makeApp(named: "Beta", bundleIdentifier: "com.example.beta", in: root)
        let storage = isolatedStorage()
        storage.saveRecentItemsSource(.application)

        let model = StartMenuModel(
            scanner: ApplicationScanner(searchRoots: [root]),
            storage: storage,
            systemRecentItemProvider: FakeSystemRecentItemProvider(items: [
                RecentItem(name: "Ignored", url: URL(fileURLWithPath: "/tmp/ignored"), kind: .document)
            ])
        )
        model.reloadApplications()
        let alpha = try #require(model.applications.first { $0.name == "Alpha" })
        let beta = try #require(model.applications.first { $0.name == "Beta" })
        storage.saveRecentIDs([beta.id, alpha.id])
        model.recentApplicationIDs = storage.loadRecentIDs()

        #expect(model.recentItems.map(\.name) == ["Beta", "Alpha"])
        #expect(model.recentItems.allSatisfy { $0.kind == .application })
    }

    @MainActor
    @Test func modelUsesSystemRecentItemsWhenSelected() {
        let storage = isolatedStorage()
        storage.saveRecentItemsSource(.system)
        storage.saveRecentApplicationLimit(2)
        let items = [
            RecentItem(name: "Preview", url: URL(fileURLWithPath: "/Applications/Preview.app"), kind: .application),
            RecentItem(name: "Plan", url: URL(fileURLWithPath: "/tmp/Plan.pdf"), kind: .document),
            RecentItem(name: "Downloads", url: URL(fileURLWithPath: "/tmp/Downloads"), kind: .folder)
        ]

        let model = StartMenuModel(
            storage: storage,
            systemRecentItemProvider: FakeSystemRecentItemProvider(items: items)
        )

        #expect(model.recentItems.map(\.name) == ["Preview", "Plan"])
    }

    @MainActor
    @Test func systemRecentItemsSortByTimeDeduplicateAndRespectLimit() {
        let first = URL(fileURLWithPath: "/tmp/Plan.pdf")
        let second = URL(fileURLWithPath: "/tmp/Notes.txt")
        let candidates = [
            SystemRecentItemCandidate(
                item: RecentItem(name: "Preview", url: URL(fileURLWithPath: "/Applications/Preview.app"), kind: .application),
                recencyDate: Date(timeIntervalSince1970: 100),
                sourceOrder: 0,
                itemOrder: 0
            ),
            SystemRecentItemCandidate(
                item: RecentItem(name: "Plan", url: first, kind: .document),
                recencyDate: Date(timeIntervalSince1970: 200),
                sourceOrder: 1,
                itemOrder: 0
            ),
            SystemRecentItemCandidate(
                item: RecentItem(name: "Plan Duplicate", url: first, kind: .document),
                recencyDate: Date(timeIntervalSince1970: 300),
                sourceOrder: 1,
                itemOrder: 1
            ),
            SystemRecentItemCandidate(
                item: RecentItem(name: "Notes", url: second, kind: .document),
                recencyDate: nil,
                sourceOrder: 1,
                itemOrder: 2
            )
        ]

        let result = SystemRecentItemProvider.sortedRecentItems(from: candidates, limit: 2)

        #expect(result.map(\.name) == ["Plan Duplicate", "Preview"])
    }

    @MainActor
    @Test func presentationPreparationResetsSearchWhenStateRestoreIsDisabled() {
        let storage = isolatedStorage()
        storage.saveRestoresStartMenuState(false)
        let model = StartMenuModel(storage: storage)
        model.searchText = "terminal"
        let originalHomeResetToken = model.homeResetToken

        model.prepareForPresentation()

        #expect(model.searchText.isEmpty)
        #expect(model.homeResetToken != originalHomeResetToken)
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

    private func isolatedStorage() -> StartMenuStorage {
        let suiteName = "iStartTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return StartMenuStorage(defaults: defaults)
    }
}

private struct FakeSystemRecentItemProvider: SystemRecentItemProviding {
    var items: [RecentItem]

    func recentItems(limit: Int) -> [RecentItem] {
        Array(items.prefix(limit))
    }
}

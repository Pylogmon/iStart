import AppKit
import Combine
import Defaults
import Foundation

@MainActor
final class StartMenuModel: ObservableObject {
    @Published var applications: [InstalledApplication] = [] {
        didSet {
            applicationsByID = Dictionary(applications.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
            applicationsByBundleID = Dictionary(
                applications.compactMap { app in app.bundleIdentifier.map { ($0, app) } },
                uniquingKeysWith: { first, _ in first }
            )
            cachedFilteredApplications = nil
        }
    }
    @Published var pinnedApplicationIDs: [String]
    @Published var recentApplicationIDs: [String]
    @Published var searchText = "" {
        didSet {
            if searchText != oldValue { cachedFilteredApplications = nil }
        }
    }
    @Published var launchError: String?
    @Published var hotKey: HotKey {
        didSet {
            defaults[.hotKey] = hotKey
        }
    }
    @Published var showSettingsAtLaunch: Bool {
        didSet {
            defaults[.showSettingsAtLaunch] = showSettingsAtLaunch
        }
    }
    @Published var showsRecommendedSection: Bool {
        didSet {
            defaults[.showsRecommendedSection] = showsRecommendedSection
        }
    }
    @Published var restoresStartMenuState: Bool {
        didSet {
            defaults[.restoresStartMenuState] = restoresStartMenuState
        }
    }
    @Published var dockIconClickBehavior: DockIconClickBehavior {
        didSet {
            defaults[.dockIconClickBehavior] = dockIconClickBehavior
        }
    }
    @Published var defaultAllAppsDisplayMode: AllAppsDisplayMode {
        didSet {
            defaults[.defaultAllAppsDisplayMode] = defaultAllAppsDisplayMode
        }
    }
    @Published private(set) var pinnedApplicationRowCount: Int
    @Published private(set) var recommendedApplicationRowCount: Int
    @Published private(set) var recentApplicationLimit: Int
    @Published private(set) var loginItemStatus: LoginItemStatus
    @Published var loginItemError: String?
    @Published private(set) var applicationSearchDirectories: [URL]
    @Published var hotKeyRegistrationStatus: HotKeyRegistrationStatus = .unknown
    @Published private(set) var searchFocusToken = UUID()
    @Published private(set) var homeResetToken = UUID()

    private var scanner: any ApplicationScanning
    private let defaults: UserDefaults
    private let loginItemManager: LoginItemManaging
    @Published private(set) var isReloadingApplications = false
    private var needsApplicationReload = false
    private var lastApplicationReload: TimeInterval?
    private var applicationsByID: [String: InstalledApplication] = [:]
    private var applicationsByBundleID: [String: InstalledApplication] = [:]
    private var cachedFilteredApplications: [InstalledApplication]?
    private var applicationDirectoryAccess: [ApplicationDirectoryAccess]

    init(
        scanner: any ApplicationScanning = ApplicationScanner(),
        defaults: UserDefaults = .standard,
        loginItemManager: LoginItemManaging = LoginItemService()
    ) {
        var scanner = scanner
        let storedBookmarks = defaults[.applicationSearchDirectoryBookmarks]
        let applicationSearchDirectoryBookmarks = storedBookmarks.map {
            ApplicationDirectoryBookmark.resolve($0)?.bookmarkData ?? $0
        }
        if applicationSearchDirectoryBookmarks != storedBookmarks {
            defaults[.applicationSearchDirectoryBookmarks] = applicationSearchDirectoryBookmarks
        }
        scanner.applicationDirectoryBookmarkData = applicationSearchDirectoryBookmarks
        self.scanner = scanner
        self.defaults = defaults
        self.loginItemManager = loginItemManager
        self.pinnedApplicationIDs = defaults[.pinnedApplicationIDs]
        let recentApplicationLimit = Defaults.clampedRecentApplicationLimit(defaults[.recentApplicationLimit])
        self.recentApplicationIDs = Array(defaults[.recentApplicationIDs].prefix(recentApplicationLimit))
        self.hotKey = Defaults.loadHotKey(from: defaults)
        self.showsRecommendedSection = defaults[.showsRecommendedSection]
        self.showSettingsAtLaunch = defaults[.showSettingsAtLaunch]
        self.restoresStartMenuState = defaults[.restoresStartMenuState]
        self.dockIconClickBehavior = defaults[.dockIconClickBehavior]
        self.defaultAllAppsDisplayMode = defaults[.defaultAllAppsDisplayMode]
        let pinnedApplicationRowCount = Defaults.clampedPinnedApplicationRowCount(defaults[.pinnedApplicationRowCount])
        self.pinnedApplicationRowCount = pinnedApplicationRowCount
        let recommendedApplicationRowCount = Defaults.clampedRecommendedApplicationRowCount(defaults[.recommendedApplicationRowCount])
        self.recommendedApplicationRowCount = recommendedApplicationRowCount
        self.recentApplicationLimit = recentApplicationLimit
        self.loginItemStatus = loginItemManager.status
        let directories = Self.applicationSearchDirectoryURLs(from: applicationSearchDirectoryBookmarks)
        self.applicationDirectoryAccess = directories.map(ApplicationDirectoryAccess.init)
        self.applicationSearchDirectories = directories
        defaults[.pinnedApplicationRowCount] = pinnedApplicationRowCount
        defaults[.recommendedApplicationRowCount] = recommendedApplicationRowCount
        defaults[.recentApplicationIDs] = recentApplicationIDs
    }

    var filteredApplications: [InstalledApplication] {
        if let cachedFilteredApplications { return cachedFilteredApplications }
        let query = ApplicationSearchIndex.normalize(searchText)
        guard !query.isEmpty else { return applications }

        let results = applications
            .enumerated()
            .compactMap { index, application -> (index: Int, application: InstalledApplication, score: Int)? in
                guard let score = ApplicationSearchMatcher.score(application, normalizedQuery: query) else { return nil }
                return (index, application, score)
            }
            .sorted { lhs, rhs in
                if lhs.score != rhs.score {
                    return lhs.score < rhs.score
                }

                return lhs.index < rhs.index
            }
            .map(\.application)
        cachedFilteredApplications = results
        return results
    }

    var pinnedApplications: [InstalledApplication] {
        let pinned = pinnedApplicationIDs.compactMap { applicationsByID[$0] }
        if !pinned.isEmpty {
            return pinned
        }

        return defaultPinnedApplications
    }

    var recentApplications: [InstalledApplication] {
        recentApplicationIDs.compactMap { applicationsByID[$0] }
    }

    var launchesAtLogin: Bool {
        loginItemStatus.isEnabled
    }

    func refreshLoginItemStatus() {
        loginItemStatus = loginItemManager.status
    }

    func setLaunchesAtLogin(_ launchesAtLogin: Bool) {
        do {
            try loginItemManager.setEnabled(launchesAtLogin)
            loginItemStatus = loginItemManager.status
            loginItemError = nil
        } catch {
            loginItemStatus = loginItemManager.status
            loginItemError = String.localizedStringWithFormat(
                String(localized: "Could not update Open at Login: %@"),
                error.localizedDescription
            )
        }
    }

    func setRecentApplicationLimit(_ limit: Int) {
        let limit = Defaults.clampedRecentApplicationLimit(limit)
        guard recentApplicationLimit != limit else { return }

        recentApplicationLimit = limit
        trimRecentApplications()
        defaults[.recentApplicationLimit] = limit
    }

    func setPinnedApplicationRowCount(_ rowCount: Int) {
        let rowCount = Defaults.clampedPinnedApplicationRowCount(rowCount)
        guard pinnedApplicationRowCount != rowCount else { return }

        pinnedApplicationRowCount = rowCount
        defaults[.pinnedApplicationRowCount] = rowCount
    }

    func setRecommendedApplicationRowCount(_ rowCount: Int) {
        let rowCount = Defaults.clampedRecommendedApplicationRowCount(rowCount)
        guard recommendedApplicationRowCount != rowCount else { return }

        recommendedApplicationRowCount = rowCount
        defaults[.recommendedApplicationRowCount] = rowCount
    }

    func reloadApplications() {
        applyApplications(scanner.scan())
    }

    func addApplicationSearchDirectory() {
        let panel = NSOpenPanel()
        panel.title = String(localized: "Add Application Folder")
        panel.message = String(localized: "Choose a folder that contains applications, such as your Applications folder.")
        panel.prompt = String(localized: "Add")
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications", isDirectory: true)

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let bookmarkData = try url.bookmarkData(
                options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            var bookmarks = defaults[.applicationSearchDirectoryBookmarks]
            let existingURLs = Self.applicationSearchDirectoryURLs(from: bookmarks)
            guard !existingURLs.contains(where: { $0.standardizedFileURL == url.standardizedFileURL }) else { return }

            bookmarks.append(bookmarkData)
            saveApplicationSearchDirectoryBookmarks(bookmarks)
            reloadApplicationsInBackground()
        } catch {
            launchError = String.localizedStringWithFormat(
                String(localized: "Could not add application folder: %@"),
                error.localizedDescription
            )
        }
    }

    func removeApplicationSearchDirectory(_ directory: URL) {
        let keptBookmarks = defaults[.applicationSearchDirectoryBookmarks].filter { bookmarkData in
            guard let url = ApplicationDirectoryBookmark.resolve(bookmarkData)?.url else { return true }

            return url.standardizedFileURL != directory.standardizedFileURL
        }

        saveApplicationSearchDirectoryBookmarks(keptBookmarks)
        reloadApplicationsInBackground()
    }

    func reloadApplicationsInBackground(force: Bool = true) {
        if isReloadingApplications {
            needsApplicationReload = needsApplicationReload || force
            return
        }

        if !force, let lastApplicationReload,
           ProcessInfo.processInfo.systemUptime - lastApplicationReload < 30 {
            return
        }
        isReloadingApplications = true

        let scanner = scanner
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let applications = scanner.scan()

            DispatchQueue.main.async {
                guard let self else { return }
                self.isReloadingApplications = false
                if self.needsApplicationReload {
                    self.needsApplicationReload = false
                    self.reloadApplicationsInBackground()
                } else {
                    if force { AppIconCache.shared.removeAllIcons() }
                    self.applyApplications(applications)
                }
            }
        }
    }

    private func applyApplications(_ applications: [InstalledApplication]) {
        if self.applications != applications {
            self.applications = applications
        }
        lastApplicationReload = ProcessInfo.processInfo.systemUptime
    }

    func focusSearch() {
        searchFocusToken = UUID()
    }

    func prepareForPresentation() {
        if !restoresStartMenuState {
            searchText = ""
            homeResetToken = UUID()
        }

        focusSearch()
    }

    func launch(_ application: InstalledApplication) {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true

        NSWorkspace.shared.openApplication(at: application.url, configuration: configuration) { [weak self] _, error in
            DispatchQueue.main.async {
                guard let self else { return }

                if let error {
                    self.launchError = "Could not open \(application.name): \(error.localizedDescription)"
                    return
                }

                self.launchError = nil
                self.rememberLaunch(application)
                NotificationCenter.default.post(name: .startMenuShouldHide, object: nil)
            }
        }
    }

    func isPinned(_ application: InstalledApplication) -> Bool {
        pinnedApplicationIDs.contains(application.id)
    }

    func togglePinned(_ application: InstalledApplication) {
        if let index = pinnedApplicationIDs.firstIndex(of: application.id) {
            pinnedApplicationIDs.remove(at: index)
        } else {
            pinnedApplicationIDs.append(application.id)
        }

        defaults[.pinnedApplicationIDs] = pinnedApplicationIDs
    }

    func resetPinnedApplications() {
        pinnedApplicationIDs.removeAll()
        defaults[.pinnedApplicationIDs] = []
    }

    func movePinnedApplication(_ source: InstalledApplication, toPositionOf destination: InstalledApplication) {
        var orderedIDs = pinnedApplicationIDs
        if orderedIDs.isEmpty {
            orderedIDs = defaultPinnedApplications.map(\.id)
        }

        guard source.id != destination.id,
              let sourceIndex = orderedIDs.firstIndex(of: source.id),
              let destinationIndex = orderedIDs.firstIndex(of: destination.id)
        else { return }

        orderedIDs.remove(at: sourceIndex)
        orderedIDs.insert(source.id, at: destinationIndex)

        pinnedApplicationIDs = orderedIDs
        defaults[.pinnedApplicationIDs] = orderedIDs
    }

    private var defaultPinnedApplications: [InstalledApplication] {
        let preferredBundleIDs = [
            "com.apple.Safari",
            "com.apple.mail",
            "com.apple.MobileSMS",
            "com.apple.finder",
            "com.apple.systempreferences",
            "com.apple.Terminal",
            "com.apple.Photos",
            "com.apple.Music",
            "com.apple.Notes",
            "com.apple.dt.Xcode",
            "com.microsoft.VSCode",
            "com.google.Chrome"
        ]

        let preferred = preferredBundleIDs.compactMap { applicationsByBundleID[$0] }
        if preferred.count >= 6 {
            return Array(preferred.prefix(18))
        }

        return Array(applications.prefix(18))
    }

    private func rememberLaunch(_ application: InstalledApplication) {
        recentApplicationIDs.removeAll { $0 == application.id }
        recentApplicationIDs.insert(application.id, at: 0)
        trimRecentApplications()
    }

    private func trimRecentApplications() {
        recentApplicationIDs = Array(recentApplicationIDs.prefix(recentApplicationLimit))
        defaults[.recentApplicationIDs] = recentApplicationIDs
    }

    private func saveApplicationSearchDirectoryBookmarks(_ bookmarks: [Data]) {
        defaults[.applicationSearchDirectoryBookmarks] = bookmarks
        scanner.applicationDirectoryBookmarkData = bookmarks
        let directories = Self.applicationSearchDirectoryURLs(from: bookmarks)
        applicationDirectoryAccess = directories.map(ApplicationDirectoryAccess.init)
        applicationSearchDirectories = directories
    }

    private static func applicationSearchDirectoryURLs(from bookmarks: [Data]) -> [URL] {
        bookmarks.compactMap { bookmarkData in
            ApplicationDirectoryBookmark.resolve(bookmarkData)?.url
        }
    }

}

private enum ApplicationSearchMatcher {
    static func score(_ application: InstalledApplication, normalizedQuery: String) -> Int? {
        var bestScore: Int?
        for key in searchKeys(for: application) {
            guard let score = key.score(for: normalizedQuery) else { continue }
            bestScore = min(bestScore ?? score, score)
        }

        return bestScore
    }

    private static func searchKeys(for application: InstalledApplication) -> [ApplicationSearchKey] {
        if !application.searchKeys.isEmpty {
            return application.searchKeys
        }

        return ApplicationSearchIndex.keys(name: application.name, bundleIdentifier: application.bundleIdentifier)
    }
}

private extension ApplicationSearchKey {
    func score(for query: String) -> Int? {
        if text == query {
            return weight
        }

        if text.hasPrefix(query) {
            return weight + 1
        }

        if text.wordInitialsMatch(query) {
            return weight + 2
        }

        if let range = text.range(of: query) {
            return weight + 10 + text.distance(from: text.startIndex, to: range.lowerBound)
        }

        if text.isSubsequenceMatch(for: query) {
            return weight + 100
        }

        return nil
    }
}

private extension String {
    func isSubsequenceMatch(for query: String) -> Bool {
        var currentIndex = startIndex

        for character in query {
            guard let matchIndex = self[currentIndex...].firstIndex(of: character) else {
                return false
            }

            currentIndex = index(after: matchIndex)
        }

        return true
    }

    func wordInitialsMatch(_ query: String) -> Bool {
        split(separator: " ").contains { word in
            word.hasPrefix(query)
        }
    }
}

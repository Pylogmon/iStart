import AppKit
import Combine
import Foundation

final class StartMenuModel: ObservableObject {
    @Published var applications: [InstalledApplication] = []
    @Published var pinnedApplicationIDs: [String]
    @Published var recentApplicationIDs: [String]
    @Published var searchText = ""
    @Published var launchError: String?
    @Published var hotKey: HotKey {
        didSet {
            storage.saveHotKey(hotKey)
        }
    }
    @Published var showSettingsAtLaunch: Bool {
        didSet {
            storage.saveShowSettingsAtLaunch(showSettingsAtLaunch)
        }
    }
    @Published var showsRecommendedSection: Bool {
        didSet {
            storage.saveShowsRecommendedSection(showsRecommendedSection)
        }
    }
    @Published var restoresStartMenuState: Bool {
        didSet {
            storage.saveRestoresStartMenuState(restoresStartMenuState)
        }
    }
    @Published private(set) var recentApplicationLimit: Int
    @Published private(set) var loginItemStatus: LoginItemStatus
    @Published var loginItemError: String?
    @Published private(set) var applicationSearchDirectories: [URL]
    @Published var hotKeyRegistrationStatus: HotKeyRegistrationStatus = .unknown
    @Published private(set) var searchFocusToken = UUID()
    @Published private(set) var homeResetToken = UUID()

    private var scanner: ApplicationScanner
    private let storage: StartMenuStorage
    private let loginItemManager: LoginItemManaging
    private var isReloadingApplications = false

    init(
        scanner: ApplicationScanner = ApplicationScanner(),
        storage: StartMenuStorage = StartMenuStorage(),
        loginItemManager: LoginItemManaging = LoginItemService()
    ) {
        var scanner = scanner
        let applicationSearchDirectoryBookmarks = storage.loadApplicationSearchDirectoryBookmarks()
        scanner.applicationDirectoryBookmarkData = applicationSearchDirectoryBookmarks
        self.scanner = scanner
        self.storage = storage
        self.loginItemManager = loginItemManager
        self.pinnedApplicationIDs = storage.loadPinnedIDs()
        self.recentApplicationIDs = storage.loadRecentIDs()
        self.hotKey = storage.loadHotKey()
        self.showsRecommendedSection = storage.loadShowsRecommendedSection()
        self.showSettingsAtLaunch = storage.loadShowSettingsAtLaunch()
        self.restoresStartMenuState = storage.loadRestoresStartMenuState()
        self.recentApplicationLimit = storage.loadRecentApplicationLimit()
        self.loginItemStatus = loginItemManager.status
        self.applicationSearchDirectories = Self.applicationSearchDirectoryURLs(from: applicationSearchDirectoryBookmarks)
        self.recentApplicationIDs = Array(recentApplicationIDs.prefix(recentApplicationLimit))
    }

    var filteredApplications: [InstalledApplication] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return applications }

        return applications
            .enumerated()
            .compactMap { index, application -> (index: Int, application: InstalledApplication, score: Int)? in
                guard let score = ApplicationSearchMatcher.score(application, query: query) else { return nil }
                return (index, application, score)
            }
            .sorted { lhs, rhs in
                if lhs.score != rhs.score {
                    return lhs.score < rhs.score
                }

                return lhs.index < rhs.index
            }
            .map(\.application)
    }

    var pinnedApplications: [InstalledApplication] {
        let indexed = Dictionary(uniqueKeysWithValues: applications.map { ($0.id, $0) })
        let pinned = pinnedApplicationIDs.compactMap { indexed[$0] }
        if !pinned.isEmpty {
            return pinned
        }

        return defaultPinnedApplications
    }

    var recentApplications: [InstalledApplication] {
        let indexed = Dictionary(uniqueKeysWithValues: applications.map { ($0.id, $0) })
        return recentApplicationIDs.compactMap { indexed[$0] }
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
        let limit = Self.clampedRecentApplicationLimit(limit)
        guard recentApplicationLimit != limit else { return }

        recentApplicationLimit = limit
        trimRecentApplications()
        storage.saveRecentApplicationLimit(limit)
    }

    func reloadApplications() {
        applications = scanner.scan()
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
            var bookmarks = storage.loadApplicationSearchDirectoryBookmarks()
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
        let keptBookmarks = storage.loadApplicationSearchDirectoryBookmarks().filter { bookmarkData in
            var isStale = false
            guard let url = try? URL(
                resolvingBookmarkData: bookmarkData,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            ), !isStale else {
                return false
            }

            return url.standardizedFileURL != directory.standardizedFileURL
        }

        saveApplicationSearchDirectoryBookmarks(keptBookmarks)
        reloadApplicationsInBackground()
    }

    func reloadApplicationsInBackground() {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.reloadApplicationsInBackground()
            }
            return
        }

        guard !isReloadingApplications else { return }
        isReloadingApplications = true

        let scanner = scanner
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let applications = scanner.scan()

            DispatchQueue.main.async {
                guard let self else { return }
                self.applications = applications
                self.isReloadingApplications = false
            }
        }
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

        storage.savePinnedIDs(pinnedApplicationIDs)
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
        storage.savePinnedIDs(orderedIDs)
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

        let indexed = Dictionary(uniqueKeysWithValues: applications.compactMap { app -> (String, InstalledApplication)? in
            guard let bundleIdentifier = app.bundleIdentifier else { return nil }
            return (bundleIdentifier, app)
        })

        let preferred = preferredBundleIDs.compactMap { indexed[$0] }
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
        storage.saveRecentIDs(recentApplicationIDs, limit: recentApplicationLimit)
    }

    private func saveApplicationSearchDirectoryBookmarks(_ bookmarks: [Data]) {
        storage.saveApplicationSearchDirectoryBookmarks(bookmarks)
        scanner.applicationDirectoryBookmarkData = bookmarks
        applicationSearchDirectories = Self.applicationSearchDirectoryURLs(from: bookmarks)
    }

    private static func applicationSearchDirectoryURLs(from bookmarks: [Data]) -> [URL] {
        bookmarks.compactMap { bookmarkData in
            var isStale = false
            guard let url = try? URL(
                resolvingBookmarkData: bookmarkData,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            ), !isStale else {
                return nil
            }

            return url
        }
    }

    private static func clampedRecentApplicationLimit(_ limit: Int) -> Int {
        min(
            max(limit, StartMenuStorage.recentApplicationLimitRange.lowerBound),
            StartMenuStorage.recentApplicationLimitRange.upperBound
        )
    }
}

private enum ApplicationSearchMatcher {
    static func score(_ application: InstalledApplication, query: String) -> Int? {
        let normalizedQuery = ApplicationSearchIndex.normalize(query)
        guard !normalizedQuery.isEmpty else { return 0 }

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
    var initials: String {
        split(separator: " ")
            .compactMap(\.first)
            .map(String.init)
            .joined()
    }

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

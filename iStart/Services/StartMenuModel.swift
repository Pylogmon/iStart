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
    @Published var hotKeyRegistrationStatus: HotKeyRegistrationStatus = .unknown
    @Published private(set) var searchFocusToken = UUID()

    private let scanner: ApplicationScanner
    private let storage: StartMenuStorage

    init(scanner: ApplicationScanner = ApplicationScanner(), storage: StartMenuStorage = StartMenuStorage()) {
        self.scanner = scanner
        self.storage = storage
        self.pinnedApplicationIDs = storage.loadPinnedIDs()
        self.recentApplicationIDs = storage.loadRecentIDs()
        self.hotKey = storage.loadHotKey()
    }

    var filteredApplications: [InstalledApplication] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return applications }

        return applications.filter { application in
            application.name.localizedCaseInsensitiveContains(query)
                || application.bundleIdentifier?.localizedCaseInsensitiveContains(query) == true
        }
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

    func reloadApplications() {
        applications = scanner.scan()
    }

    func focusSearch() {
        searchFocusToken = UUID()
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
        recentApplicationIDs = Array(recentApplicationIDs.prefix(8))
        storage.saveRecentIDs(recentApplicationIDs)
    }
}

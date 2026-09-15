import AppKit
import Combine
import Defaults
import Foundation
import SwiftUI
import Testing
@testable import iStart

@MainActor
struct PerformanceCompatibilityTests {
    @Test func backgroundReloadCoalescesRequestsAndUsesLatestResult() async throws {
        let recorder = ScanRecorder()
        let model = StartMenuModel(scanner: RecordingScanner(recorder: recorder), defaults: isolatedDefaults())

        model.reloadApplicationsInBackground()
        model.reloadApplicationsInBackground()
        model.reloadApplicationsInBackground()
        model.reloadApplicationsInBackground(force: false)
        try await waitForReload(model)

        #expect(recorder.calls == 2)
        #expect(!recorder.didScanOnMainThread)
        #expect(model.applications.map(\.id) == ["scan-2-bookmarks-0"])
    }

    @Test func automaticReloadReusesRecentIndexAndForcedReloadBypassesIt() async throws {
        let recorder = ScanRecorder()
        let model = StartMenuModel(scanner: RecordingScanner(recorder: recorder), defaults: isolatedDefaults())

        model.reloadApplicationsInBackground(force: false)
        try await waitForReload(model)
        model.reloadApplicationsInBackground(force: false)

        #expect(!model.isReloadingApplications)
        #expect(recorder.calls == 1)

        model.reloadApplicationsInBackground()
        try await waitForReload(model)
        #expect(recorder.calls == 2)
    }

    @Test func removingDirectoryDuringScanUsesUpdatedDirectories() async throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let defaults = isolatedDefaults()
        defaults[.applicationSearchDirectoryBookmarks] = [try bookmark(for: root)]
        let recorder = ScanRecorder()
        let model = StartMenuModel(scanner: RecordingScanner(recorder: recorder), defaults: defaults)

        model.reloadApplicationsInBackground()
        model.removeApplicationSearchDirectory(root)
        try await waitForReload(model)

        #expect(recorder.calls == 2)
        #expect(model.applicationSearchDirectories.isEmpty)
        #expect(model.applications.map(\.id) == ["scan-2-bookmarks-0"])
    }

    @Test func unchangedReloadDoesNotRepublishApplications() async throws {
        let recorder = ScanRecorder()
        let model = StartMenuModel(
            scanner: RecordingScanner(recorder: recorder, variesResults: false), defaults: isolatedDefaults()
        )
        model.reloadApplicationsInBackground()
        try await waitForReload(model)
        var changes = 0
        let observation = model.$applications.dropFirst().sink { _ in changes += 1 }
        defer { observation.cancel() }

        model.reloadApplicationsInBackground()
        try await waitForReload(model)

        #expect(recorder.calls == 2)
        #expect(changes == 0)
    }

    @Test func cachedSearchAndLookupsFollowApplicationChanges() {
        let model = StartMenuModel(defaults: isolatedDefaults())
        var notes = application("notes", name: "Notes")
        notes.bundleIdentifier = nil
        let terminal = application("terminal", name: "Terminal")
        model.applications = [notes, terminal]
        model.pinnedApplicationIDs = [notes.id]
        model.recentApplicationIDs = [terminal.id]
        model.searchText = "note"
        #expect(model.filteredApplications == [notes])
        #expect(model.filteredApplications == [notes])

        var renamedNotes = notes
        renamedNotes.name = "Journal"
        model.applications = [renamedNotes]
        #expect(model.filteredApplications.isEmpty)
        #expect(model.pinnedApplications == [renamedNotes])
        #expect(model.recentApplications.isEmpty)

        model.searchText = "journal"
        #expect(model.filteredApplications == [renamedNotes])
        model.searchText = " \n "
        #expect(model.filteredApplications == [renamedNotes])
    }

    @Test func searchKeepsChineseInitialsAndWidthInsensitiveMatching() {
        let model = StartMenuModel(defaults: isolatedDefaults())
        model.applications = [application("wechat", name: "微信"), application("code", name: "Visual Studio Code")]
        model.searchText = "ｗｘ"
        #expect(model.filteredApplications.map(\.id) == ["wechat"])
        model.searchText = "ＶＳＣ"
        #expect(model.filteredApplications.map(\.id) == ["code"])
    }

    @Test func duplicateBundleIdentifiersDoNotCrashPinnedLookup() {
        let model = StartMenuModel(defaults: isolatedDefaults())
        var first = application("first", name: "First")
        var second = application("second", name: "Second")
        first.bundleIdentifier = "com.example.shared"
        second.bundleIdentifier = first.bundleIdentifier
        model.applications = [first, second]

        #expect(model.pinnedApplications == [first, second])
        model.pinnedApplicationIDs = [second.id]
        #expect(model.pinnedApplications == [second])
    }

    @Test func scannerHandlesUppercaseExtensionsAndExternalSymlinks() async throws {
        let root = try temporaryDirectory()
        let externalRoot = try temporaryDirectory()
        defer {
            try? FileManager.default.removeItem(at: root)
            try? FileManager.default.removeItem(at: externalRoot)
        }
        let uppercaseApp = try makeApp("Uppercase.APP", in: root)
        let mixedCaseApp = try makeApp("Mixed.App", in: root)
        let externalApp = try makeApp("External.app", in: externalRoot)
        try FileManager.default.createSymbolicLink(
            at: root.appendingPathComponent("Linked.app"), withDestinationURL: externalApp
        )
        try Data().write(to: root.appendingPathComponent("NotAnApplication.app"))
        try FileManager.default.createSymbolicLink(
            at: root.appendingPathComponent("Broken.app"),
            withDestinationURL: root.appendingPathComponent("Missing.app")
        )
        let scanner = ApplicationScanner(searchRoots: [root, externalRoot, root])
        let apps = await Task.detached { scanner.scan() }.value

        #expect(apps.count == 3)
        #expect(Set(apps.map { $0.url.resolvingSymlinksInPath().path }) == Set([uppercaseApp, mixedCaseApp, externalApp].map(\.path)))
        #expect(Set(apps.map(\.name)) == Set(["Uppercase", "Mixed", "Linked"]))
    }

    @Test func movedFolderBookmarkStillResolvesAndIndexesApps() throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let original = root.appendingPathComponent("Original", isDirectory: true)
        let moved = root.appendingPathComponent("Moved", isDirectory: true)
        _ = try makeApp("Example.app", in: original)
        let oldBookmark = try bookmark(for: original)
        try FileManager.default.moveItem(at: original, to: moved)

        let resolved = try #require(ApplicationDirectoryBookmark.resolve(oldBookmark))
        #expect(resolved.url.standardizedFileURL == moved.standardizedFileURL)
        var isStale = false
        _ = try URL(
            resolvingBookmarkData: resolved.bookmarkData, options: [.withSecurityScope, .withoutUI],
            relativeTo: nil, bookmarkDataIsStale: &isStale
        )
        #expect(!isStale)

        let defaults = isolatedDefaults()
        defaults[.applicationSearchDirectoryBookmarks] = [oldBookmark]
        let model = StartMenuModel(scanner: ApplicationScanner(searchRoots: []), defaults: defaults)
        model.reloadApplications()
        #expect(model.applications.map(\.name) == ["Example"])
        #expect(model.applicationSearchDirectories.map(\.standardizedFileURL) == [moved.standardizedFileURL])
    }

    @Test func removingDirectoryPreservesOtherUnresolvableBookmarks() throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let defaults = isolatedDefaults()
        let unavailableBookmark = Data("unavailable bookmark".utf8)
        defaults[.applicationSearchDirectoryBookmarks] = [try bookmark(for: root), unavailableBookmark]
        let model = StartMenuModel(scanner: ApplicationScanner(searchRoots: []), defaults: defaults)

        model.removeApplicationSearchDirectory(root)

        #expect(defaults[.applicationSearchDirectoryBookmarks] == [unavailableBookmark])
    }

    @Test func iconCacheReusesImagesButRefreshesChangedAppsAfterExpiry() throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let app = try makeApp("Icon.app", in: root)
        let infoURL = app.appendingPathComponent("Contents/Info.plist")
        let resources = app.appendingPathComponent("Contents/Resources", isDirectory: true)
        try FileManager.default.createDirectory(at: resources, withIntermediateDirectories: true)
        let iconURL = resources.appendingPathComponent("AppIcon.icns")
        try Data().write(to: iconURL)
        let info = try PropertyListSerialization.data(
            fromPropertyList: ["CFBundleIconFile": "AppIcon.icns"], format: .xml, options: 0
        )
        try info.write(to: infoURL)
        var now: TimeInterval = 0
        var loads = 0
        let originalImage = NSImage(size: NSSize(width: 128, height: 128))
        let cache = AppIconCache(uptime: { now }, loadIcon: { _ in
            loads += 1
            return originalImage
        })
        let first = cache.icon(forFile: app.path, size: 42)
        first.size = NSSize(width: 1, height: 1)
        #expect(cache.icon(forFile: app.path, size: 42).size == NSSize(width: 42, height: 42))
        #expect(originalImage.size == NSSize(width: 128, height: 128))

        try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSince1970: 1234)], ofItemAtPath: infoURL.path)
        now = 10
        _ = cache.icon(forFile: app.path, size: 42)
        #expect(loads == 1)
        now = 31
        _ = cache.icon(forFile: app.path, size: 42)
        #expect(loads == 2)
        now = 62
        _ = cache.icon(forFile: app.path, size: 42)
        #expect(loads == 2)

        try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSince1970: 1234)], ofItemAtPath: iconURL.path)
        now = 93
        _ = cache.icon(forFile: app.path, size: 42)
        #expect(loads == 3)

        cache.removeAllIcons()
        _ = cache.icon(forFile: app.path, size: 42)
        #expect(loads == 4)
    }

    @Test func iconCachePreservesFractionalSizes() {
        let cache = AppIconCache(loadIcon: { _ in NSImage(size: NSSize(width: 128, height: 128)) })
        #expect(cache.icon(forFile: "/missing", size: 21.1).size.width == 21.1)
        #expect(cache.icon(forFile: "/missing", size: 21.4).size.width == 21.4)
    }

    @Test func menuContentFitsCompactDisplays() {
        let model = StartMenuModel(defaults: isolatedDefaults())
        let categories = ["utilities", "productivity", "games", "developer-tools"]
        model.applications = categories.map { category in
            var app = application(category, name: category)
            app.categoryIdentifier = "public.app-category.\(category)"
            return app
        }
        let host = NSHostingController(rootView: StartMenuView(model: model))
        host.sizingOptions = []
        let size = host.sizeThatFits(in: NSSize(width: 520, height: 500))

        #expect(size.width <= 520)
        #expect(size.height <= 500)
    }

    private func waitForReload(_ model: StartMenuModel) async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(5))
        while model.isReloadingApplications, ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(!model.isReloadingApplications)
    }

    private func application(_ id: String, name: String) -> InstalledApplication {
        InstalledApplication(id: id, name: name, bundleIdentifier: "com.example.\(id)", path: "/\(id).app")
    }

    private func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("iStartReview-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func makeApp(_ name: String, in root: URL) throws -> URL {
        let app = root.appendingPathComponent(name, isDirectory: true)
        let contents = app.appendingPathComponent("Contents", isDirectory: true)
        try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)
        let info = ["CFBundleIdentifier": "com.example.\(name)", "CFBundlePackageType": "APPL"]
        let data = try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0)
        try data.write(to: contents.appendingPathComponent("Info.plist"))
        return app
    }

    private func bookmark(for url: URL) throws -> Data {
        try url.bookmarkData(
            options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess],
            includingResourceValuesForKeys: nil, relativeTo: nil
        )
    }

    private func isolatedDefaults() -> UserDefaults {
        UserDefaults(suiteName: "iStartReview-\(UUID().uuidString)")!
    }
}

private struct RecordingScanner: ApplicationScanning {
    let recorder: ScanRecorder
    var variesResults = true
    var applicationDirectoryBookmarkData: [Data] = []

    func scan() -> [InstalledApplication] {
        let number = recorder.record()
        let id = "scan-\(variesResults ? number : 0)-bookmarks-\(applicationDirectoryBookmarkData.count)"
        return [InstalledApplication(id: id, name: id, path: "/\(id).app")]
    }
}

private final class ScanRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0
    private var scannedOnMainThread = false

    var calls: Int { lock.withLock { count } }
    var didScanOnMainThread: Bool { lock.withLock { scannedOnMainThread } }

    func record() -> Int {
        lock.withLock {
            count += 1
            scannedOnMainThread = scannedOnMainThread || Thread.isMainThread
            return count
        }
    }
}

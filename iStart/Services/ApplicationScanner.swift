import Darwin
import Foundation

nonisolated protocol ApplicationScanning: Sendable {
    var applicationDirectoryBookmarkData: [Data] { get set }
    func scan() -> [InstalledApplication]
}

nonisolated struct ApplicationScanner: ApplicationScanning {
    var searchRoots: [URL] = ApplicationScanner.defaultSearchRoots
    var applicationDirectoryBookmarkData: [Data] = []

    func scan() -> [InstalledApplication] {
        var appsByID: [String: InstalledApplication] = [:]
        var seenPaths: Set<String> = []
        let authorizedRoots = authorizedSearchRoots()
        defer {
            authorizedRoots.forEach { $0.stopAccessing() }
        }

        for root in uniqueSearchRoots(searchRoots + authorizedRoots.map(\.url)) where FileManager.default.fileExists(atPath: root.path) {
            for url in applicationURLs(in: root) {
                guard seenPaths.insert(url.resolvingSymlinksInPath().standardizedFileURL.path).inserted else { continue }
                guard let application = makeApplication(from: url) else { continue }

                if appsByID[application.id] == nil {
                    appsByID[application.id] = application
                }
            }
        }

        return appsByID.values.sorted {
            $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
    }

    private func applicationURLs(in root: URL) -> [URL] {
        let keys: [URLResourceKey] = [.localizedNameKey, .isDirectoryKey]
        var seenPaths: Set<String> = []
        var appURLs: [URL] = []

        func append(_ url: URL) {
            guard (try? url.resolvingSymlinksInPath().resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true else { return }
            let path = url.standardizedFileURL.path
            guard seenPaths.insert(path).inserted else { return }
            appURLs.append(url)
        }

        if let topLevelURLs = try? FileManager.default.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: keys,
            options: []
        ) {
            topLevelURLs
                .filter { $0.pathExtension.lowercased() == "app" }
                .forEach(append)
        }

        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return appURLs
        }

        for case let url as URL in enumerator where url.pathExtension.lowercased() == "app" {
            append(url)
            enumerator.skipDescendants()
        }

        return appURLs
    }

    private func makeApplication(from url: URL) -> InstalledApplication? {
        let info = AppInfoReader.infoDictionary(for: url)
        let localizedInfo = AppInfoReader.localizedInfoDictionary(for: url)
        let bundleIdentifier = info["CFBundleIdentifier"] as? String
        let categoryIdentifier = info["LSApplicationCategoryType"] as? String
        let name = AppNameResolver.displayName(for: url, info: info, localizedInfo: localizedInfo)
        let id = bundleIdentifier ?? url.path

        return InstalledApplication(
            id: id,
            name: name,
            bundleIdentifier: bundleIdentifier,
            categoryIdentifier: categoryIdentifier,
            path: url.path,
            searchKeys: ApplicationSearchIndex.keys(name: name, bundleIdentifier: bundleIdentifier)
        )
    }

    private func uniqueSearchRoots(_ roots: [URL]) -> [URL] {
        var seenPaths: Set<String> = []
        return roots.filter { root in
            let path = root.standardizedFileURL.path
            return seenPaths.insert(path).inserted
        }
    }

    private func authorizedSearchRoots() -> [AuthorizedSearchRoot] {
        applicationDirectoryBookmarkData.compactMap { bookmarkData in
            guard let url = ApplicationDirectoryBookmark.resolve(bookmarkData)?.url else { return nil }

            return AuthorizedSearchRoot(url: url, didStartAccessing: url.startAccessingSecurityScopedResource())
        }
    }

    private static var realHomeDirectory: URL {
        guard let home = getpwuid(getuid())?.pointee.pw_dir else {
            return FileManager.default.homeDirectoryForCurrentUser
        }

        return URL(fileURLWithFileSystemRepresentation: home, isDirectory: true, relativeTo: nil)
    }

    private static var defaultSearchRoots: [URL] {
        [
            URL(fileURLWithPath: "/Applications", isDirectory: true),
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications", isDirectory: true),
            realHomeDirectory.appendingPathComponent("Applications", isDirectory: true),
            URL(fileURLWithPath: "/System/Applications", isDirectory: true),
            URL(fileURLWithPath: "/System/Cryptexes/App/System/Applications", isDirectory: true),
            URL(fileURLWithPath: "/System/Volumes/Preboot/Cryptexes/App/System/Applications", isDirectory: true)
        ] + FileManager.default.urls(for: .applicationDirectory, in: .userDomainMask)
    }
}

nonisolated enum ApplicationSearchIndex {
    static func keys(name: String, bundleIdentifier: String?) -> [ApplicationSearchKey] {
        let spacedName = normalize(name, keepingSpaces: true)
        let spacedPinyin = normalize(pinyinSearchText(for: name), keepingSpaces: true)
        let keys: [ApplicationSearchKey] = [
            ApplicationSearchKey(text: spacedName.replacingOccurrences(of: " ", with: ""), weight: 0),
            ApplicationSearchKey(text: spacedName, weight: 10),
            ApplicationSearchKey(text: initials(for: spacedName), weight: 30),
            ApplicationSearchKey(text: spacedPinyin.replacingOccurrences(of: " ", with: ""), weight: 20),
            ApplicationSearchKey(text: spacedPinyin, weight: 25),
            ApplicationSearchKey(text: initials(for: spacedPinyin), weight: 35),
            ApplicationSearchKey(text: normalize(bundleIdentifier ?? ""), weight: 60)
        ]

        var seen: Set<String> = []
        return keys.sorted { $0.weight < $1.weight }.filter {
            !$0.text.isEmpty && seen.insert($0.text).inserted
        }
    }

    static func normalize(_ text: String, keepingSpaces: Bool = false) -> String {
        let folded = text.folding(options: [.diacriticInsensitive, .caseInsensitive, .widthInsensitive], locale: .current)
        let allowed = folded.unicodeScalars.map { scalar -> Character in
            if CharacterSet.alphanumerics.contains(scalar) {
                return Character(scalar)
            }

            return keepingSpaces ? " " : "\0"
        }

        let normalized = String(allowed)
            .replacingOccurrences(of: "\0", with: "")

        guard keepingSpaces else { return normalized }
        return normalized
            .split(separator: " ")
            .joined(separator: " ")
    }

    private static func pinyinSearchText(for text: String) -> String {
        text
            .applyingTransform(.mandarinToLatin, reverse: false)?
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            ?? text
    }

    private static func initials(for text: String) -> String {
        text
            .split(separator: " ")
            .compactMap(\.first)
            .map(String.init)
            .joined()
    }
}

private nonisolated struct AuthorizedSearchRoot {
    let url: URL
    let didStartAccessing: Bool

    func stopAccessing() {
        if didStartAccessing {
            url.stopAccessingSecurityScopedResource()
        }
    }
}

private enum AppInfoReader {
    nonisolated static func infoDictionary(for appURL: URL) -> [String: Any] {
        let infoURL = appURL
            .appendingPathComponent("Contents", isDirectory: true)
            .appendingPathComponent("Info.plist")
        return plistDictionary(at: infoURL) ?? [:]
    }

    nonisolated static func localizedInfoDictionary(for appURL: URL) -> [String: String] {
        let resourcesURL = appURL
            .appendingPathComponent("Contents", isDirectory: true)
            .appendingPathComponent("Resources", isDirectory: true)
        guard let localizations = try? FileManager.default.contentsOfDirectory(
            at: resourcesURL,
            includingPropertiesForKeys: nil
        )
            .filter({ $0.pathExtension == "lproj" })
            .map({ $0.deletingPathExtension().lastPathComponent })
        else {
            return [:]
        }

        for localization in Bundle.preferredLocalizations(from: localizations) {
            let stringsURL = resourcesURL
                .appendingPathComponent("\(localization).lproj", isDirectory: true)
                .appendingPathComponent("InfoPlist.strings")
            if let strings = plistDictionary(at: stringsURL) as? [String: String] {
                return strings
            }
        }

        return [:]
    }

    nonisolated private static func plistDictionary(at url: URL) -> [String: Any]? {
        guard let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil)
        else {
            return nil
        }

        return plist as? [String: Any]
    }
}

private enum AppNameResolver {
    nonisolated static func displayName(
        for url: URL,
        info: [String: Any],
        localizedInfo: [String: String]
    ) -> String {
        func fileSystemName(_ name: String?) -> String? {
            // Launch Services can append another .app to bundles using .APP or .App.
            if let name, name.caseInsensitiveCompare(url.lastPathComponent + ".app") == .orderedSame {
                return String(name.dropLast(4))
            }
            return name
        }

        let candidates = [
            localizedInfo["CFBundleDisplayName"],
            info["CrAppModeShortcutName"] as? String,
            localizedInfo["CFBundleName"],
            fileSystemName(try? url.resourceValues(forKeys: [.localizedNameKey]).localizedName),
            fileSystemName(FileManager.default.displayName(atPath: url.path)),
            info["CFBundleDisplayName"] as? String,
            info["CFBundleName"] as? String,
            url.deletingPathExtension().lastPathComponent
        ]

        return candidates
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .map(stripApplicationExtension)
            .first { !$0.isEmpty }
            ?? url.deletingPathExtension().lastPathComponent
    }

    nonisolated private static func stripApplicationExtension(_ name: String) -> String {
        name.lowercased().hasSuffix(".app") ? String(name.dropLast(4)) : name
    }
}

import AppKit
import Foundation

struct ApplicationScanner {
    var searchRoots: [URL] = [
        URL(fileURLWithPath: "/Applications", isDirectory: true),
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications", isDirectory: true),
        URL(fileURLWithPath: "/System/Applications", isDirectory: true)
    ]

    func scan() -> [InstalledApplication] {
        var appsByID: [String: InstalledApplication] = [:]

        for root in searchRoots where FileManager.default.fileExists(atPath: root.path) {
            let keys: [URLResourceKey] = [.isApplicationKey, .localizedNameKey, .isDirectoryKey]
            guard let enumerator = FileManager.default.enumerator(
                at: root,
                includingPropertiesForKeys: keys,
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else {
                continue
            }

            for case let url as URL in enumerator {
                guard url.pathExtension == "app" else { continue }
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

    private func makeApplication(from url: URL) -> InstalledApplication? {
        let bundle = Bundle(url: url)
        let bundleIdentifier = bundle?.bundleIdentifier
        let name = AppNameResolver.displayName(for: url, bundle: bundle)
        let id = bundleIdentifier ?? url.path

        return InstalledApplication(
            id: id,
            name: name,
            bundleIdentifier: bundleIdentifier,
            path: url.path
        )
    }
}

private enum AppNameResolver {
    static func displayName(for url: URL, bundle: Bundle?) -> String {
        let candidates = [
            localizedInfoValue("CFBundleDisplayName", in: bundle),
            localizedInfoValue("CFBundleName", in: bundle),
            bundle?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String,
            bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String,
            FileManager.default.displayName(atPath: url.path),
            (try? url.resourceValues(forKeys: [.localizedNameKey]).localizedName),
            url.deletingPathExtension().lastPathComponent
        ]

        return candidates
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .map(stripApplicationExtension)
            .first { !$0.isEmpty }
            ?? url.deletingPathExtension().lastPathComponent
    }

    private static func localizedInfoValue(_ key: String, in bundle: Bundle?) -> String? {
        bundle?.localizedInfoDictionary?[key] as? String
    }

    private static func stripApplicationExtension(_ name: String) -> String {
        let extensions = [".app", ".APP"]
        for suffix in extensions where name.hasSuffix(suffix) {
            return String(name.dropLast(suffix.count))
        }

        return name
    }
}

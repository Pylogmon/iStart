import AppKit
import Foundation

final class AppIconCache {
    static let shared = AppIconCache()

    private let cache = NSCache<NSString, AppIconCacheEntry>()

    private init() {}

    func icon(forFile path: String, size: CGFloat) -> NSImage {
        let key = cacheKey(path: path, size: size)
        let appURL = URL(fileURLWithPath: path)

        if let entry = cache.object(forKey: key),
           iconVersion(for: appURL, iconResourceURL: entry.iconResourceURL) == entry.version {
            return entry.imageCopy()
        }

        let iconResourceURL = iconResourceURL(for: appURL)
        let image = NSWorkspace.shared.icon(forFile: path)
        image.size = NSSize(width: size, height: size)

        let entry = AppIconCacheEntry(
            image: image,
            iconResourceURL: iconResourceURL,
            version: iconVersion(for: appURL, iconResourceURL: iconResourceURL)
        )
        cache.setObject(entry, forKey: key)

        return entry.imageCopy()
    }

    func removeAllIcons() {
        cache.removeAllObjects()
    }

    private func cacheKey(path: String, size: CGFloat) -> NSString {
        "\(path)|\(Int(size.rounded()))" as NSString
    }

    private func iconVersion(for appURL: URL, iconResourceURL: URL?) -> AppIconVersion {
        let infoPlistURL = appURL
            .appendingPathComponent("Contents", isDirectory: true)
            .appendingPathComponent("Info.plist")

        return AppIconVersion(
            appModificationDate: modificationDate(for: appURL),
            infoPlistModificationDate: modificationDate(for: infoPlistURL),
            iconResourceModificationDate: iconResourceURL.flatMap(modificationDate)
        )
    }

    private func modificationDate(for url: URL) -> Date? {
        try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
    }

    private func iconResourceURL(for appURL: URL) -> URL? {
        let infoPlistURL = appURL
            .appendingPathComponent("Contents", isDirectory: true)
            .appendingPathComponent("Info.plist")
        guard let info = NSDictionary(contentsOf: infoPlistURL) as? [String: Any],
              let iconFileName = iconFileName(in: info)
        else {
            return nil
        }

        let resourcesURL = appURL
            .appendingPathComponent("Contents", isDirectory: true)
            .appendingPathComponent("Resources", isDirectory: true)
        let candidateNames: [String]
        if URL(fileURLWithPath: iconFileName).pathExtension.isEmpty {
            candidateNames = [iconFileName, "\(iconFileName).icns"]
        } else {
            candidateNames = [iconFileName]
        }

        return candidateNames
            .map { resourcesURL.appendingPathComponent($0) }
            .first { FileManager.default.fileExists(atPath: $0.path) }
    }

    private func iconFileName(in info: [String: Any]) -> String? {
        if let iconFile = info["CFBundleIconFile"] as? String {
            return iconFile
        }

        guard let primaryIcon = (info["CFBundleIcons"] as? [String: Any])?["CFBundlePrimaryIcon"] as? [String: Any],
              let iconFiles = primaryIcon["CFBundleIconFiles"] as? [String],
              let iconFile = iconFiles.last
        else {
            return nil
        }

        return iconFile
    }
}

private final class AppIconCacheEntry {
    let image: NSImage
    let iconResourceURL: URL?
    let version: AppIconVersion

    init(image: NSImage, iconResourceURL: URL?, version: AppIconVersion) {
        self.image = image
        self.iconResourceURL = iconResourceURL
        self.version = version
    }

    func imageCopy() -> NSImage {
        image.copy() as? NSImage ?? image
    }
}

private struct AppIconVersion: Equatable {
    var appModificationDate: Date?
    var infoPlistModificationDate: Date?
    var iconResourceModificationDate: Date?
}

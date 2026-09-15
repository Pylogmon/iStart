import AppKit
import Foundation

@MainActor
final class AppIconCache {
    static let shared = AppIconCache()

    private let cache = NSCache<NSString, AppIconCacheEntry>()
    private let validationInterval: TimeInterval
    private let uptime: () -> TimeInterval
    private let loadIcon: (String) -> NSImage

    init(
        validationInterval: TimeInterval = 30,
        uptime: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime },
        loadIcon: @escaping (String) -> NSImage = { NSWorkspace.shared.icon(forFile: $0) }
    ) {
        self.validationInterval = validationInterval
        self.uptime = uptime
        self.loadIcon = loadIcon
        cache.countLimit = 128
    }

    func icon(forFile path: String, size: CGFloat) -> NSImage {
        let key = cacheKey(path: path, size: size)
        let appURL = URL(fileURLWithPath: path)
        let now = uptime()

        if let entry = cache.object(forKey: key) {
            // Hovering, typing, and selection changes must not stat every visible app.
            if now - entry.lastValidation < validationInterval {
                return entry.imageCopy()
            }
            if iconVersion(for: appURL, iconResourceURL: entry.iconResourceURL) == entry.version {
                entry.lastValidation = now
                return entry.imageCopy()
            }
        }

        let iconResourceURL = iconResourceURL(for: appURL)
        let image = loadIcon(path).copy() as? NSImage ?? NSImage(size: NSSize(width: size, height: size))
        image.size = NSSize(width: size, height: size)

        let entry = AppIconCacheEntry(
            image: image,
            iconResourceURL: iconResourceURL,
            version: iconVersion(for: appURL, iconResourceURL: iconResourceURL),
            lastValidation: now
        )
        cache.setObject(entry, forKey: key)

        return entry.imageCopy()
    }

    func removeAllIcons() {
        cache.removeAllObjects()
    }

    private func cacheKey(path: String, size: CGFloat) -> NSString {
        "\(path)|\(size)" as NSString
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
        var url = url
        url.removeCachedResourceValue(forKey: .contentModificationDateKey)
        return try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
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
    var lastValidation: TimeInterval

    init(image: NSImage, iconResourceURL: URL?, version: AppIconVersion, lastValidation: TimeInterval) {
        self.image = image
        self.iconResourceURL = iconResourceURL
        self.version = version
        self.lastValidation = lastValidation
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

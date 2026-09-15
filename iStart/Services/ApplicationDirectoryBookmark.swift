import Foundation

nonisolated enum ApplicationDirectoryBookmark {
    struct Resolution {
        let url: URL
        let bookmarkData: Data
    }

    static func resolve(_ data: Data) -> Resolution? {
        var isStale = false
        guard let url = try? URL(
            resolvingBookmarkData: data,
            options: [.withSecurityScope, .withoutUI],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else { return nil }

        guard isStale else { return Resolution(url: url, bookmarkData: data) }

        // A stale bookmark can still resolve after a folder is moved or renamed.
        let didStartAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing { url.stopAccessingSecurityScopedResource() }
        }
        let refreshedData = try? url.bookmarkData(
            options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        return Resolution(url: url, bookmarkData: refreshedData ?? data)
    }
}

// Keep selected folders accessible for icons and launches after a scan finishes.
nonisolated final class ApplicationDirectoryAccess: Sendable {
    let url: URL
    private let didStartAccessing: Bool

    init(url: URL) {
        self.url = url
        didStartAccessing = url.startAccessingSecurityScopedResource()
    }

    deinit {
        if didStartAccessing { url.stopAccessingSecurityScopedResource() }
    }
}

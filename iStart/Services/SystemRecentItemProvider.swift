import AppKit
import CoreServices
import Darwin
import Foundation

protocol SystemRecentItemProviding {
    nonisolated func recentItems(limit: Int) -> [RecentItem]
}

struct SystemRecentItemCandidate: Sendable {
    nonisolated let item: RecentItem
    nonisolated let recencyDate: Date?
    nonisolated let sourceOrder: Int
    nonisolated let itemOrder: Int
}

struct SystemRecentItemProvider: SystemRecentItemProviding {
    nonisolated func recentItems(limit: Int) -> [RecentItem] {
        guard limit > 0 else { return [] }

        var candidates: [SystemRecentItemCandidate] = []

        for (sourceOrder, source) in RecentSharedFileListSource.all.enumerated() {
            for (itemOrder, url) in urls(for: source.listType).enumerated() {
                guard canOpen(url) else { continue }

                candidates.append(
                    SystemRecentItemCandidate(
                        item: RecentItem(
                            name: displayName(for: url),
                            url: url,
                            kind: kind(for: url, fallback: source.kind)
                        ),
                        recencyDate: recencyDate(for: url),
                        sourceOrder: sourceOrder,
                        itemOrder: itemOrder
                    )
                )
            }
        }

        return Self.sortedRecentItems(from: candidates, limit: limit)
    }

    nonisolated static func sortedRecentItems(from candidates: [SystemRecentItemCandidate], limit: Int) -> [RecentItem] {
        guard limit > 0 else { return [] }

        let sortedCandidates = candidates.sorted { lhs, rhs in
            switch (lhs.recencyDate, rhs.recencyDate) {
            case let (lhsDate?, rhsDate?) where lhsDate != rhsDate:
                return lhsDate > rhsDate
            case (.some, .none):
                return true
            case (.none, .some):
                return false
            default:
                if lhs.sourceOrder != rhs.sourceOrder {
                    return lhs.sourceOrder < rhs.sourceOrder
                }

                return lhs.itemOrder < rhs.itemOrder
            }
        }

        var seenURLs = Set<URL>()
        var recentItems: [RecentItem] = []

        for candidate in sortedCandidates {
            let item = candidate.item
            let standardizedURL = item.url.isFileURL ? item.url.standardizedFileURL : item.url
            guard !seenURLs.contains(standardizedURL) else { continue }

            seenURLs.insert(standardizedURL)
            recentItems.append(item)

            if recentItems.count >= limit {
                return recentItems
            }
        }

        return recentItems
    }

    nonisolated static func deduplicated(_ items: [RecentItem], limit: Int) -> [RecentItem] {
        sortedRecentItems(
            from: items.enumerated().map { index, item in
                SystemRecentItemCandidate(
                    item: item,
                    recencyDate: nil,
                    sourceOrder: 0,
                    itemOrder: index
                )
            },
            limit: limit
        )
    }

    private nonisolated func urls(for listType: CFString) -> [URL] {
        guard let api = SharedFileListAPI.current,
              let list = api.create(nil, listType, nil)?.takeRetainedValue(),
              let snapshot = api.copySnapshot(list, nil)?.takeRetainedValue() as? [LSSharedFileListItem]
        else { return [] }

        return snapshot.compactMap { item in
            api.copyResolvedURL(item, 0, nil)?.takeRetainedValue() as URL?
        }
    }

    private nonisolated func recencyDate(for url: URL) -> Date? {
        guard url.isFileURL else { return nil }

        let values = try? url.resourceValues(
            forKeys: [
                .contentAccessDateKey,
                .contentModificationDateKey,
                .creationDateKey
            ]
        )

        return values?.contentAccessDate ?? values?.contentModificationDate ?? values?.creationDate
    }

    private nonisolated func canOpen(_ url: URL) -> Bool {
        if url.isFileURL {
            return FileManager.default.fileExists(atPath: url.path)
        }

        return NSWorkspace.shared.urlForApplication(toOpen: url) != nil
    }

    private nonisolated func displayName(for url: URL) -> String {
        if url.isFileURL {
            if let localizedName = try? url.resourceValues(forKeys: [.localizedNameKey]).localizedName,
               !localizedName.isEmpty {
                return localizedName
            }

            let lastPathComponent = url.deletingPathExtension().lastPathComponent
            return lastPathComponent.isEmpty ? url.path : lastPathComponent
        }

        return url.host(percentEncoded: false) ?? url.absoluteString
    }

    private nonisolated func kind(for url: URL, fallback: RecentItemKind) -> RecentItemKind {
        guard url.isFileURL else { return fallback }

        if (try? url.resourceValues(forKeys: [.isApplicationKey]).isApplication) == true {
            return .application
        }

        if (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true {
            return .folder
        }

        return fallback
    }
}

private struct RecentSharedFileListSource: Sendable {
    nonisolated let listType: CFString
    nonisolated let kind: RecentItemKind

    nonisolated static let all = [
        RecentSharedFileListSource(
            listType: "com.apple.LSSharedFileList.RecentApplications" as NSString,
            kind: .application
        ),
        RecentSharedFileListSource(
            listType: "com.apple.LSSharedFileList.RecentDocuments" as NSString,
            kind: .document
        ),
        RecentSharedFileListSource(
            listType: "com.apple.LSSharedFileList.RecentServers" as NSString,
            kind: .server
        )
    ]
}

private struct SharedFileListAPI: @unchecked Sendable {
    typealias Create = @convention(c) (CFAllocator?, CFString, CFTypeRef?) -> Unmanaged<LSSharedFileList>?
    typealias CopySnapshot = @convention(c) (LSSharedFileList, UnsafeMutablePointer<UInt32>?) -> Unmanaged<CFArray>?
    typealias CopyResolvedURL = @convention(c) (LSSharedFileListItem, UInt32, UnsafeMutablePointer<Unmanaged<CFError>?>?) -> Unmanaged<CFURL>?

    nonisolated let create: Create
    nonisolated let copySnapshot: CopySnapshot
    nonisolated let copyResolvedURL: CopyResolvedURL

    nonisolated static let current: SharedFileListAPI? = {
        guard let handle = dlopen(nil, RTLD_NOW),
              let create = dlsym(handle, "LSSharedFileListCreate"),
              let copySnapshot = dlsym(handle, "LSSharedFileListCopySnapshot"),
              let copyResolvedURL = dlsym(handle, "LSSharedFileListItemCopyResolvedURL")
        else { return nil }

        return SharedFileListAPI(
            create: unsafeBitCast(create, to: Create.self),
            copySnapshot: unsafeBitCast(copySnapshot, to: CopySnapshot.self),
            copyResolvedURL: unsafeBitCast(copyResolvedURL, to: CopyResolvedURL.self)
        )
    }()
}

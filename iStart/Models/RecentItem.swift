import Foundation

enum RecentItemsSource: String, Codable, CaseIterable, Identifiable, Sendable {
    case system
    case application

    var id: Self { self }
}

enum RecentItemKind: String, Codable, Sendable {
    case application
    case document
    case folder
    case server
    case other
}

struct RecentItem: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let name: String
    let url: URL
    let kind: RecentItemKind
    let applicationID: String?

    nonisolated init(
        id: String? = nil,
        name: String,
        url: URL,
        kind: RecentItemKind,
        applicationID: String? = nil
    ) {
        self.id = id ?? url.absoluteString
        self.name = name
        self.url = url
        self.kind = kind
        self.applicationID = applicationID
    }
}

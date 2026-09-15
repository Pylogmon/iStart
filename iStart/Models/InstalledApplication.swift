import Foundation

nonisolated struct InstalledApplication: Identifiable, Codable, Hashable, Sendable {
    var id: String
    var name: String
    var bundleIdentifier: String?
    var categoryIdentifier: String?
    var path: String
    var searchKeys: [ApplicationSearchKey] = []

    var url: URL {
        URL(fileURLWithPath: path)
    }
}

nonisolated struct ApplicationSearchKey: Codable, Hashable, Sendable {
    var text: String
    var weight: Int
}

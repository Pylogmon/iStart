import Foundation

struct InstalledApplication: Identifiable, Codable, Hashable {
    var id: String
    var name: String
    var bundleIdentifier: String?
    var path: String
    var searchKeys: [ApplicationSearchKey] = []

    var url: URL {
        URL(fileURLWithPath: path)
    }
}

struct ApplicationSearchKey: Codable, Hashable {
    var text: String
    var weight: Int
}

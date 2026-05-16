import Foundation

struct InstalledApplication: Identifiable, Codable, Hashable {
    var id: String
    var name: String
    var bundleIdentifier: String?
    var path: String

    var url: URL {
        URL(fileURLWithPath: path)
    }
}

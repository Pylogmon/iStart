import Defaults
import Foundation

enum AllAppsDisplayMode: String, CaseIterable, Defaults.Serializable, Identifiable {
    case categories
    case list

    var id: String { rawValue }

    var title: String {
        switch self {
        case .categories:
            return String(localized: "Categories")
        case .list:
            return String(localized: "List")
        }
    }

    var systemImage: String {
        switch self {
        case .categories:
            return "square.grid.2x2"
        case .list:
            return "list.bullet"
        }
    }
}

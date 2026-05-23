import Foundation

enum DockIconClickBehavior: String, CaseIterable, Identifiable {
    case openSettings
    case toggleStartMenu

    var id: String { rawValue }

    var title: String {
        switch self {
        case .openSettings:
            String(localized: "Open Settings")
        case .toggleStartMenu:
            String(localized: "Toggle Start Menu")
        }
    }
}

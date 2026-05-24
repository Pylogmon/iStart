import Carbon.HIToolbox
import Defaults
import Foundation

struct HotKey: Codable, Defaults.Serializable, Equatable, Identifiable {
    var id: String { rawValue }

    let rawValue: String
    let title: String
    let keyCode: Int
    let carbonModifiers: Int

    var localizedTitle: String {
        String(localized: String.LocalizationValue(title))
    }

    var displayTitle: String {
        localizedTitle
    }

    static let commandSpace = HotKey(rawValue: "commandSpace", title: "Command Space", keyCode: kVK_Space, carbonModifiers: cmdKey)
    static let optionSpace = HotKey(rawValue: "optionSpace", title: "Option Space", keyCode: kVK_Space, carbonModifiers: optionKey)

    static let all: [HotKey] = [
        .commandSpace,
        .optionSpace
    ]
}

enum HotKeyRegistrationStatus: Equatable {
    case unknown
    case registered
    case failed(OSStatus)

    var message: String {
        switch self {
        case .unknown:
            String(localized: "Hot key has not been registered yet.")
        case .registered:
            String(localized: "Global shortcut is active.")
        case .failed(let status):
            String.localizedStringWithFormat(String(localized: "Shortcut could not be registered. It may already be used by macOS or another app. OSStatus %d."), status)
        }
    }
}

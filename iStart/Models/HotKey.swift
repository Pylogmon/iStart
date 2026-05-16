import Carbon.HIToolbox
import Foundation

struct HotKey: Codable, Equatable, Identifiable {
    var id: String { rawValue }

    let rawValue: String
    let title: String
    let keyCode: Int
    let carbonModifiers: Int

    var localizedTitle: String {
        String(localized: String.LocalizationValue(title))
    }

    static let commandSpace = HotKey(rawValue: "commandSpace", title: "Command Space", keyCode: kVK_Space, carbonModifiers: cmdKey)
    static let optionSpace = HotKey(rawValue: "optionSpace", title: "Option Space", keyCode: kVK_Space, carbonModifiers: optionKey)
    static let controlSpace = HotKey(rawValue: "controlSpace", title: "Control Space", keyCode: kVK_Space, carbonModifiers: controlKey)
    static let commandOptionSpace = HotKey(rawValue: "commandOptionSpace", title: "Command Option Space", keyCode: kVK_Space, carbonModifiers: cmdKey | optionKey)

    static let all: [HotKey] = [
        .commandSpace,
        .optionSpace,
        .controlSpace,
        .commandOptionSpace
    ]

    static func fromRawValue(_ rawValue: String) -> HotKey {
        all.first { $0.rawValue == rawValue } ?? .commandSpace
    }
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

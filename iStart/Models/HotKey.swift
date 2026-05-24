import Carbon.HIToolbox
import Defaults
import Foundation

struct HotKey: Codable, Defaults.Serializable, Equatable, Identifiable {
    var id: String { rawValue }

    let rawValue: String
    let title: String
    let keyCode: Int
    let carbonModifiers: Int
    let keyEquivalent: String

    var localizedTitle: String {
        if Self.all.contains(where: { $0.rawValue == rawValue }) {
            return String(localized: String.LocalizationValue(title))
        }

        return title
    }

    var displayTokens: [String] {
        modifierDisplayTokens + [keyDisplayName]
    }

    var displayTitle: String {
        displayTokens.joined(separator: " ")
    }

    var modifierDisplayTokens: [String] {
        [
            (cmdKey, "⌘"),
            (optionKey, "⌥"),
            (controlKey, "⌃"),
            (shiftKey, "⇧")
        ].compactMap { modifier, token in
            carbonModifiers & modifier != 0 ? token : nil
        }
    }

    var keyDisplayName: String {
        switch keyCode {
        case kVK_Space:
            return String(localized: "Spacebar")
        case kVK_Return:
            return "Return"
        case kVK_Tab:
            return "Tab"
        case kVK_Escape:
            return "Esc"
        case kVK_Delete:
            return "Delete"
        case kVK_ForwardDelete:
            return "Forward Delete"
        case kVK_LeftArrow:
            return "←"
        case kVK_RightArrow:
            return "→"
        case kVK_UpArrow:
            return "↑"
        case kVK_DownArrow:
            return "↓"
        default:
            if let functionKeyName = Self.functionKeyNames[keyCode] {
                return functionKeyName
            }

            return keyEquivalent.isEmpty ? "Key \(keyCode)" : keyEquivalent.uppercased()
        }
    }

    static let commandSpace = HotKey(rawValue: "commandSpace", title: "Command Space", keyCode: kVK_Space, carbonModifiers: cmdKey, keyEquivalent: "Space")
    static let optionSpace = HotKey(rawValue: "optionSpace", title: "Option Space", keyCode: kVK_Space, carbonModifiers: optionKey, keyEquivalent: "Space")
    static let controlSpace = HotKey(rawValue: "controlSpace", title: "Control Space", keyCode: kVK_Space, carbonModifiers: controlKey, keyEquivalent: "Space")
    static let commandOptionSpace = HotKey(rawValue: "commandOptionSpace", title: "Command Option Space", keyCode: kVK_Space, carbonModifiers: cmdKey | optionKey, keyEquivalent: "Space")

    static let all: [HotKey] = [
        .commandSpace,
        .optionSpace
    ]

    static func fromRawValue(_ rawValue: String) -> HotKey {
        all.first { $0.rawValue == rawValue } ?? .commandSpace
    }

    static func recorded(keyCode: Int, carbonModifiers: Int, keyEquivalent: String) -> HotKey {
        let hotKey = HotKey(
            rawValue: "recorded:\(keyCode):\(carbonModifiers):\(keyEquivalent)",
            title: "",
            keyCode: keyCode,
            carbonModifiers: carbonModifiers,
            keyEquivalent: keyEquivalent
        )

        return HotKey(
            rawValue: hotKey.rawValue,
            title: hotKey.displayTitle,
            keyCode: hotKey.keyCode,
            carbonModifiers: hotKey.carbonModifiers,
            keyEquivalent: hotKey.keyEquivalent
        )
    }

    private static let functionKeyNames = [
        kVK_F1: "F1",
        kVK_F2: "F2",
        kVK_F3: "F3",
        kVK_F4: "F4",
        kVK_F5: "F5",
        kVK_F6: "F6",
        kVK_F7: "F7",
        kVK_F8: "F8",
        kVK_F9: "F9",
        kVK_F10: "F10",
        kVK_F11: "F11",
        kVK_F12: "F12",
        kVK_F13: "F13",
        kVK_F14: "F14",
        kVK_F15: "F15",
        kVK_F16: "F16",
        kVK_F17: "F17",
        kVK_F18: "F18",
        kVK_F19: "F19",
        kVK_F20: "F20"
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

import Foundation
import ServiceManagement

enum LoginItemStatus: Equatable {
    case disabled
    case enabled
    case requiresApproval

    var isEnabled: Bool {
        switch self {
        case .enabled, .requiresApproval:
            true
        case .disabled:
            false
        }
    }

    var message: String? {
        switch self {
        case .disabled, .enabled:
            nil
        case .requiresApproval:
            String(localized: "Open at Login requires approval in System Settings.")
        }
    }
}

protocol LoginItemManaging {
    var status: LoginItemStatus { get }

    func setEnabled(_ enabled: Bool) throws
}

struct LoginItemService: LoginItemManaging {
    var status: LoginItemStatus {
        switch SMAppService.mainApp.status {
        case .notRegistered:
            .disabled
        case .enabled:
            .enabled
        case .requiresApproval:
            .requiresApproval
        case .notFound:
            .disabled
        @unknown default:
            .disabled
        }
    }

    func setEnabled(_ enabled: Bool) throws {
        if enabled {
            guard status != .enabled, status != .requiresApproval else { return }
            try SMAppService.mainApp.register()
        } else {
            guard status != .disabled else { return }
            try SMAppService.mainApp.unregister()
        }
    }
}

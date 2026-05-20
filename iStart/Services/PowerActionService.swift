import AppKit
import Carbon
import Darwin
import Foundation
import IOKit.pwr_mgt

enum PowerAction: String, CaseIterable, Identifiable {
    case shutDown
    case restart
    case sleep
    case lockScreen
    case logOut

    var id: String { rawValue }

    static let accountActions: [PowerAction] = [.logOut, .lockScreen]
    static let powerMenuActions: [PowerAction] = [.shutDown, .restart, .sleep]

    var title: String {
        switch self {
        case .shutDown:
            String(localized: "Shut Down")
        case .restart:
            String(localized: "Restart")
        case .sleep:
            String(localized: "Sleep")
        case .lockScreen:
            String(localized: "Lock Screen")
        case .logOut:
            String(localized: "Log Out")
        }
    }

    var systemImage: String {
        switch self {
        case .shutDown:
            "power"
        case .restart:
            "restart"
        case .sleep:
            "moon"
        case .lockScreen:
            "lock"
        case .logOut:
            "rectangle.portrait.and.arrow.right"
        }
    }

    var requiresConfirmation: Bool {
        switch self {
        case .shutDown, .restart, .logOut:
            true
        case .sleep, .lockScreen:
            false
        }
    }

    var confirmationTitle: String {
        switch self {
        case .shutDown:
            String(localized: "Shut Down This Mac?")
        case .restart:
            String(localized: "Restart This Mac?")
        case .logOut:
            String(localized: "Log Out?")
        case .sleep, .lockScreen:
            title
        }
    }

    var confirmationMessage: String {
        switch self {
        case .shutDown:
            String(localized: "Open apps will be asked to quit before the Mac shuts down.")
        case .restart:
            String(localized: "Open apps will be asked to quit before the Mac restarts.")
        case .logOut:
            String(localized: "Open apps will be asked to quit before you log out.")
        case .sleep, .lockScreen:
            ""
        }
    }
}

struct PowerActionService {
    func perform(_ action: PowerAction) throws {
        switch action {
        case .shutDown:
            try sendSystemAppleEvent(kAEShutDown)
        case .restart:
            try sendSystemAppleEvent(kAERestart)
        case .sleep:
            try sleepSystem()
        case .lockScreen:
            try lockScreen()
        case .logOut:
            try sendSystemAppleEvent(kAEReallyLogOut)
        }
    }

    private func sleepSystem() throws {
        let powerPort = IOPMFindPowerManagement(mach_port_t(MACH_PORT_NULL))
        guard powerPort != 0 else {
            throw PowerActionError.couldNotFindPowerManagementPort
        }

        defer {
            IOServiceClose(powerPort)
        }

        let status = IOPMSleepSystem(powerPort)
        guard status == kIOReturnSuccess else {
            throw PowerActionError.osStatus(Int32(status))
        }
    }

    private func lockScreen() throws {
        if let cgSessionURL = firstExistingExecutableURL(in: [
            "/System/Library/CoreServices/Menu Extras/User.menu/Contents/Resources/CGSession"
        ]) {
            try runProcess(at: cgSessionURL, arguments: ["-suspend"])
            return
        }

        if let pmsetURL = firstExistingExecutableURL(in: ["/usr/bin/pmset"]) {
            try runProcess(at: pmsetURL, arguments: ["displaysleepnow"])
            return
        }

        if let screenSaverURL = firstExistingExecutableURL(in: [
            "/System/Library/CoreServices/ScreenSaverEngine.app/Contents/MacOS/ScreenSaverEngine"
        ]) {
            try runProcess(at: screenSaverURL, arguments: [])
            return
        }

        throw PowerActionError.lockScreenHelperNotFound
    }

    private func firstExistingExecutableURL(in paths: [String]) -> URL? {
        paths
            .map { URL(fileURLWithPath: $0) }
            .first { FileManager.default.isExecutableFile(atPath: $0.path) }
    }

    private func runProcess(at executableURL: URL, arguments: [String]) throws {
        let process = Process()
        process.executableURL = executableURL
        process.arguments = arguments

        do {
            try process.run()
        } catch {
            throw PowerActionError.lockScreenFailed(error.localizedDescription)
        }
    }

    private func sendSystemAppleEvent(_ eventID: AEEventID) throws {
        var processSerialNumber = ProcessSerialNumber(highLongOfPSN: 0, lowLongOfPSN: UInt32(kSystemProcess))
        var target = AEAddressDesc()
        var createStatus = AECreateDesc(
            typeProcessSerialNumber,
            &processSerialNumber,
            MemoryLayout<ProcessSerialNumber>.size,
            &target
        )
        guard createStatus == noErr else {
            throw PowerActionError.osStatus(Int32(createStatus))
        }

        defer {
            AEDisposeDesc(&target)
        }

        var event = AppleEvent()
        createStatus = AECreateAppleEvent(
            AEEventClass(kCoreEventClass),
            eventID,
            &target,
            AEReturnID(kAutoGenerateReturnID),
            AETransactionID(kAnyTransactionID),
            &event
        )
        guard createStatus == noErr else {
            throw PowerActionError.osStatus(Int32(createStatus))
        }

        defer {
            AEDisposeDesc(&event)
        }

        let sendStatus = AESendMessage(&event, nil, AESendMode(kAENoReply), kAEDefaultTimeout)
        guard sendStatus == noErr else {
            throw PowerActionError.osStatus(sendStatus)
        }
    }
}

private enum PowerActionError: LocalizedError {
    case couldNotFindPowerManagementPort
    case lockScreenHelperNotFound
    case lockScreenFailed(String)
    case osStatus(Int32)

    var errorDescription: String? {
        switch self {
        case .couldNotFindPowerManagementPort:
            String(localized: "Could not access system power management.")
        case .lockScreenHelperNotFound:
            String(localized: "Could not find a system lock screen helper.")
        case .lockScreenFailed(let reason):
            String.localizedStringWithFormat(String(localized: "Could not lock the screen: %@"), reason)
        case .osStatus(let status):
            String.localizedStringWithFormat(String(localized: "The system returned OSStatus %d."), status)
        }
    }
}

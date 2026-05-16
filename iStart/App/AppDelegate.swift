import AppKit
import Carbon.HIToolbox
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var windowController: StartMenuWindowController?
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private weak var model: StartMenuModel?

    private static weak var sharedDelegate: AppDelegate?

    func applicationDidFinishLaunching(_ notification: Notification) {
        Self.sharedDelegate = self
        NSApp.setActivationPolicy(.regular)

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            let model = self.resolveModel()
            self.model = model
            self.windowController = StartMenuWindowController(model: model)
            self.installHotKeyHandler()
            self.registerCurrentHotKey()
            self.windowController?.showAndFocusSearch()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        toggleStartMenu()
        return false
    }

    func showStartMenu() {
        resolveWindowController().showAndFocusSearch()
    }

    func toggleStartMenu() {
        resolveWindowController().toggle()
    }

    func registerCurrentHotKey() {
        guard let model else { return }
        unregisterHotKey()

        let signature = OSType(UInt32(UInt8(ascii: "i")) << 24 | UInt32(UInt8(ascii: "S")) << 16 | UInt32(UInt8(ascii: "t")) << 8 | UInt32(UInt8(ascii: "r")))
        let hotKeyID = EventHotKeyID(signature: signature, id: 1)
        let status = RegisterEventHotKey(
            UInt32(model.hotKey.keyCode),
            UInt32(model.hotKey.carbonModifiers),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        model.hotKeyRegistrationStatus = status == noErr ? .registered : .failed(status)
    }

    func updateHotKey(_ hotKey: HotKey) {
        model?.hotKey = hotKey
        registerCurrentHotKey()
    }

    private func resolveModel() -> StartMenuModel {
        if let model {
            return model
        }

        let model = AppDependencies.startMenuModel
        self.model = model
        return model
    }

    private func resolveWindowController() -> StartMenuWindowController {
        if let windowController {
            return windowController
        }

        let controller = StartMenuWindowController(model: resolveModel())
        windowController = controller
        return controller
    }

    private func installHotKeyHandler() {
        guard eventHandlerRef == nil else { return }

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let handler: EventHandlerUPP = { _, event, _ in
            guard let event else { return noErr }

            var hotKeyID = EventHotKeyID()
            let status = GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hotKeyID
            )

            if status == noErr, hotKeyID.id == 1 {
                DispatchQueue.main.async {
                    AppDelegate.sharedDelegate?.toggleStartMenu()
                }
            }

            return noErr
        }

        InstallEventHandler(GetApplicationEventTarget(), handler, 1, &eventType, nil, &eventHandlerRef)
    }

    private func unregisterHotKey() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
    }
}

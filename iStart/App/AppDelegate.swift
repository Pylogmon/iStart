import AppKit
import Carbon.HIToolbox
import Settings
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var windowController: StartMenuWindowController?
    private var settingsWindowController: SettingsWindowController?
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
            self.windowController = StartMenuWindowController(model: model) { [weak self] in
                self?.showSettings()
            }
            self.installHotKeyHandler()
            self.registerCurrentHotKey()
            self.presentInitialStartMenuIfNeeded()
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

    func showSettings() {
        let model = resolveModel()

        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController(
                panes: [
                    Settings.Pane(
                        identifier: Settings.PaneIdentifier("general"),
                        title: String(localized: "General"),
                        toolbarIcon: settingsIcon(systemName: "gearshape")
                    ) {
                        GeneralSettingsPane(model: model, hotKeySelection: hotKeySelection(for: model))
                            .frame(width: 540)
                    },
                    Settings.Pane(
                        identifier: Settings.PaneIdentifier("applications"),
                        title: String(localized: "Applications"),
                        toolbarIcon: settingsIcon(systemName: "app.dashed")
                    ) {
                        ApplicationSettingsPane(model: model)
                            .frame(width: 600)
                    }
                ]
            )
        }

        settingsWindowController?.show()
        NSApp.activate(ignoringOtherApps: true)
        settingsWindowController?.window?.makeKeyAndOrderFront(nil)
        settingsWindowController?.window?.orderFrontRegardless()
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
        resolveModel().hotKey = hotKey
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

        let controller = StartMenuWindowController(model: resolveModel()) { [weak self] in
            self?.showSettings()
        }
        windowController = controller
        return controller
    }

    private func presentInitialStartMenuIfNeeded() {
        let model = resolveModel()
        model.refreshLoginItemStatus()

        if wasLaunchedAsLoginItem {
            model.reloadApplicationsInBackground()
            return
        }

        resolveWindowController().showAndFocusSearch()
    }

    private var wasLaunchedAsLoginItem: Bool {
        guard let event = NSAppleEventManager.shared().currentAppleEvent else { return false }

        return event.eventID == kAEOpenApplication
            && event.paramDescriptor(forKeyword: keyAEPropData)?.enumCodeValue == keyAELaunchedAsLogInItem
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

    private func settingsIcon(systemName: String) -> NSImage {
        NSImage(systemSymbolName: systemName, accessibilityDescription: nil)
            ?? NSImage(named: NSImage.applicationIconName)
            ?? NSImage(size: NSSize(width: 24, height: 24))
    }

    private func hotKeySelection(for model: StartMenuModel) -> Binding<HotKey> {
        Binding {
            model.hotKey
        } set: { [weak self] hotKey in
            model.hotKey = hotKey
            self?.registerCurrentHotKey()
        }
    }

    private func unregisterHotKey() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
    }
}

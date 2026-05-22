import AppKit
import SwiftUI

@main
struct iStartApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = AppDependencies.startMenuModel
    @AppStorage(StartMenuStorage.showsMenuBarExtraDefaultsKey) private var showsMenuBarExtra = true

    var body: some Scene {
        MenuBarExtra("iStart", systemImage: "square.grid.3x3.fill", isInserted: $showsMenuBarExtra) {
            Button {
                appDelegate.showStartMenu()
            } label: {
                Label("Show Start Menu",systemImage: "square.grid.3x3.fill")
            }
            .keyboardShortcut(.space, modifiers: .command)

            Button {
                appDelegate.showSettings()
            } label: {
                Label("Open Settings", systemImage: "gearshape")
            }
            .keyboardShortcut(",", modifiers: .command)

            Divider()

            Button {
                NSApp.terminate(nil)
            } label: {
                Label("Quit iStart", systemImage: "xmark.rectangle")
            }
            .keyboardShortcut("q", modifiers: .command)
        }
        .menuBarExtraStyle(.menu)
        .commands {
            CommandGroup(replacing: .newItem) { }
            CommandGroup(replacing: .appSettings) {
                Button {
                    appDelegate.showSettings()
                } label: {
                    Label(String(localized: "Settings") + "...", systemImage: "gearshape")
                }
                .keyboardShortcut(",", modifiers: .command)
            }

            CommandMenu("iStart") {
                Button("Show Start Menu") {
                    appDelegate.showStartMenu()
                }
                .keyboardShortcut(.space, modifiers: .command)
            }
        }
        .environmentObject(model)
    }
}

enum AppDependencies {
    static let startMenuModel = StartMenuModel()
}

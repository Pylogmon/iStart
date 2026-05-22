import AppKit
import SwiftUI

@main
struct iStartApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = AppDependencies.startMenuModel
    @AppStorage(StartMenuStorage.showsMenuBarExtraDefaultsKey) private var showsMenuBarExtra = true

    var body: some Scene {
        MenuBarExtra("iStart", systemImage: "square.grid.3x3.fill", isInserted: $showsMenuBarExtra) {
            Button("Show Start Menu") {
                appDelegate.showStartMenu()
            }
            .keyboardShortcut(.space, modifiers: .command)

            Button("Settings") {
                appDelegate.showSettings()
            }
            .keyboardShortcut(",", modifiers: .command)

            Divider()

            Button("Quit iStart") {
                NSApp.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
        }
        .menuBarExtraStyle(.menu)
        .commands {
            CommandGroup(replacing: .newItem) { }
            CommandGroup(replacing: .appSettings) {
                Button("Settings") {
                    appDelegate.showSettings()
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

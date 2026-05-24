import AppKit
import Defaults
import SwiftUI

@main
struct iStartApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = AppDependencies.startMenuModel
    @Default(.showsMenuBarExtra) private var showsMenuBarExtra

    var body: some Scene {
        MenuBarExtra("iStart", systemImage: "square.grid.3x3.fill", isInserted: menuBarExtraInsertion) {
            Button {
                appDelegate.showStartMenu()
            } label: {
                Label("Show Start Menu",systemImage: "square.grid.3x3.fill")
            }

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
            }
        }
        .environmentObject(model)
    }

    private var menuBarExtraInsertion: Binding<Bool> {
        Binding {
            showsMenuBarExtra
        } set: { isInserted in
            guard showsMenuBarExtra != isInserted else { return }

            // MenuBarExtra can call this setter during SwiftUI updates; defer the Defaults write to avoid mutating state mid-update.
            DispatchQueue.main.async {
                guard showsMenuBarExtra != isInserted else { return }

                showsMenuBarExtra = isInserted
            }
        }
    }
}

enum AppDependencies {
    static let startMenuModel = StartMenuModel()
}

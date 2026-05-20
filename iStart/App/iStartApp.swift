import SwiftUI

@main
struct iStartApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = AppDependencies.startMenuModel
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        Window("Settings", id: "settings") {
            SettingsView(model: model)
                .frame(minWidth: 800, minHeight: 520)
        }
        .defaultSize(width: 850, height: 620)
        .defaultLaunchBehavior(model.showsSettingsWindowOnLaunch ? .presented : .suppressed)
        .commands {
            CommandGroup(replacing: .newItem) { }

            CommandGroup(before: .appTermination) {
                Button {
                    openWindow(id: "settings")
                } label: {
                    Label(NSLocalizedString("Settings", comment: "") + "...", systemImage: "gear")
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

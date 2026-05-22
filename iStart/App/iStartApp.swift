import SwiftUI

@main
struct iStartApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = AppDependencies.startMenuModel

    var body: some Scene {
        WindowGroup("Settings", id: "settings") {
            SettingsView(model: model)
                .frame(minWidth: 720, minHeight: 520)
        }
        .defaultSize(width: 760, height: 540)
        .commands {
            CommandGroup(replacing: .newItem) { }

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

import SwiftUI

@main
struct iStartApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = AppDependencies.startMenuModel

    var body: some Scene {
        Settings {
            SettingsView(model: model)
                .frame(width: 440)
        }
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

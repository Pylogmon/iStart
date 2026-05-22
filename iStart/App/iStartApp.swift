import SwiftUI

@main
struct iStartApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = AppDependencies.startMenuModel
    @State private var hiddenMenu = false

    var body: some Scene {
        MenuBarExtra("", isInserted: $hiddenMenu) {
            EmptyView()
        }
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

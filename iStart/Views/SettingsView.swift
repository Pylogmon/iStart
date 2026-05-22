import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: StartMenuModel

    var body: some View {
        TabView {
            GeneralSettingsPane(model: model, hotKeySelection: hotKeySelection)
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }

            ApplicationSettingsPane(model: model)
                .tabItem {
                    Label("Applications", systemImage: "app.dashed")
                }
        }
        .padding(.top, 8)
    }

    private var hotKeySelection: Binding<HotKey> {
        Binding {
            model.hotKey
        } set: { hotKey in
            model.hotKey = hotKey
            (NSApp.delegate as? AppDelegate)?.registerCurrentHotKey()
        }
    }
}

struct GeneralSettingsPane: View {
    @ObservedObject var model: StartMenuModel
    let hotKeySelection: Binding<HotKey>

    var body: some View {
        Form {
            Section {
                ShortcutPickerRow(
                    title: String(localized: "Show iStart"),
                    selectedHotKey: hotKeySelection.wrappedValue,
                    status: model.hotKeyRegistrationStatus
                ) { hotKey in
                    hotKeySelection.wrappedValue = hotKey
                }
            }
            header: {
                Text("Shortcut")
            }
            footer: {
                Text("Choose a global keyboard shortcut for opening iStart from anywhere.")
            }

            Section {
                Toggle("Show recommended section", isOn: $model.showsRecommendedSection)
                Toggle("Restore last menu state", isOn: $model.restoresStartMenuState)
            }
            header: {
                Text("Start Menu")
            }
            footer: {
                Text("When turned off, iStart opens to the home view every time.")
            }

            Section {
                Toggle("Open at Login", isOn: launchesAtLogin)

                if let message = model.loginItemStatus.message {
                    Label(message, systemImage: "exclamationmark.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let error = model.loginItemError {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            header: {
                Text("Login")
            }
            footer: {
                Text("When iStart opens at login, it runs in the background without showing the Start menu.")
            }
        }
        .formStyle(.grouped)
        .padding(.horizontal, 24)
        .padding(.vertical, 18)
    }

    private var launchesAtLogin: Binding<Bool> {
        Binding {
            model.launchesAtLogin
        } set: { launchesAtLogin in
            model.setLaunchesAtLogin(launchesAtLogin)
        }
    }
}

private struct ShortcutPickerRow: View {
    let title: String
    let selectedHotKey: HotKey
    let status: HotKeyRegistrationStatus
    let onSelect: (HotKey) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 16) {
                Text(title)

                Spacer(minLength: 24)

                Menu {
                    ForEach(HotKey.all) { hotKey in
                        Button {
                            onSelect(hotKey)
                        } label: {
                            HStack(spacing: 8) {
                                if hotKey == selectedHotKey {
                                    Image(systemName: "checkmark")
                                }

                                ShortcutInlineLabel(hotKey: hotKey)
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        ShortcutInlineLabel(hotKey: selectedHotKey)

                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
            }

            Label {
                Text(status.message)
                    .fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: status.systemImage)
            }
            .font(.caption)
            .foregroundStyle(status.foregroundStyle)

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Label {
                    Text("If Command Space is still used by Spotlight, turn off Spotlight's keyboard shortcut to avoid conflicts.")
                        .fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: "magnifyingglass")
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                Spacer(minLength: 12)

                Button("Go to System Settings") {
                    SystemSettingsOpener.openSpotlightShortcutsPage()
                }
                .controlSize(.small)
            }
        }
    }
}

private struct ShortcutInlineLabel: View {
    let hotKey: HotKey

    var body: some View {
        Text(verbatim: hotKey.displayTitle)
            .monospaced()
            .accessibilityLabel(Text(verbatim: hotKey.localizedTitle))
    }
}

private extension HotKeyRegistrationStatus {
    var systemImage: String {
        switch self {
        case .unknown:
            "keyboard"
        case .registered:
            "checkmark.circle.fill"
        case .failed:
            "exclamationmark.triangle.fill"
        }
    }

    var foregroundStyle: Color {
        switch self {
        case .unknown:
            .secondary
        case .registered:
            .secondary
        case .failed:
            .orange
        }
    }
}

struct ApplicationSettingsPane: View {
    @ObservedObject var model: StartMenuModel
    @State private var isResetPinnedAppsConfirmationPresented = false

    var body: some View {
        Form {
            Section {
                LabeledContent("Indexed applications") {
                    HStack(spacing: 12) {
                        Text(String.localizedStringWithFormat(String(localized: "%lld apps indexed"), model.applications.count))
                            .foregroundStyle(.secondary)

                        Button("Rebuild Index") {
                            model.reloadApplicationsInBackground()
                        }
                    }
                }
            }
            header: {
                Text("Indexing")
            }
            footer: {
                Text("iStart indexes applications from the standard macOS application folders and any extra folders listed below.")
            }

            Section {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("Additional application folders")

                        Spacer(minLength: 16)

                        Button("Add Folder") {
                            model.addApplicationSearchDirectory()
                        }
                    }

                    if model.applicationSearchDirectories.isEmpty {
                        ContentUnavailableView(
                            "No Additional Folders",
                            systemImage: "folder",
                            description: Text("Add your user Applications folder to index Chrome PWA apps in sandbox mode.")
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(model.applicationSearchDirectories, id: \.standardizedFileURL) { directory in
                                ApplicationFolderRow(directory: directory) {
                                    model.removeApplicationSearchDirectory(directory)
                                }

                                if directory != model.applicationSearchDirectories.last {
                                    Divider()
                                        .padding(.leading, 26)
                                }
                            }
                        }
                        .background(.background, in: RoundedRectangle(cornerRadius: 8))
                        .overlay {
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(.separator)
                        }
                    }
                }
            }
            header: {
                Text("Application folders")
            }

            Section {
                Button("Reset Pinned Apps", role: .destructive) {
                    isResetPinnedAppsConfirmationPresented = true
                }
            }
            header: {
                Text("Reset")
            }
            footer: {
                Text("Pinned apps will fall back to the default set the next time the Start menu is shown.")
            }
        }
        .formStyle(.grouped)
        .padding(.horizontal, 24)
        .padding(.vertical, 18)
        .confirmationDialog(
            "Reset Pinned Apps?",
            isPresented: $isResetPinnedAppsConfirmationPresented
        ) {
            Button("Reset Pinned Apps", role: .destructive) {
                resetPinnedApps()
            }

            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This removes your pinned app choices and restores the default pinned apps.")
        }
    }

    private func resetPinnedApps() {
        model.pinnedApplicationIDs.removeAll()
        StartMenuStorage().savePinnedIDs([])
    }
}

private struct ApplicationFolderRow: View {
    let directory: URL
    let remove: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "folder")
                .foregroundStyle(.secondary)
                .frame(width: 18)

            Text(verbatim: directory.path)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer(minLength: 12)

            Button {
                remove()
            } label: {
                Image(systemName: "minus.circle")
                    .imageScale(.medium)
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
            .help(Text("Remove Folder"))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
    }
}

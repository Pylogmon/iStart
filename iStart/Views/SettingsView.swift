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

    private var hotKeySelection: Binding<String> {
        Binding {
            model.hotKey.rawValue
        } set: { rawValue in
            let hotKey = HotKey.fromRawValue(rawValue)
            (NSApp.delegate as? AppDelegate)?.updateHotKey(hotKey)
        }
    }
}

private struct GeneralSettingsPane: View {
    @ObservedObject var model: StartMenuModel
    let hotKeySelection: Binding<String>

    var body: some View {
        Form {
            Section {
                LabeledContent("Show iStart") {
                    Picker("Show iStart", selection: hotKeySelection) {
                        ForEach(HotKey.all) { hotKey in
                            Text(verbatim: hotKey.localizedTitle).tag(hotKey.rawValue)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 220)
                }

                Text(model.hotKeyRegistrationStatus.message)
                    .font(.caption)
                    .foregroundStyle(model.hotKeyRegistrationStatus == .registered ? Color.secondary : Color.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }
            header: {
                Text("Shortcut")
            }

            Section {
                Toggle("Show recommended section", isOn: $model.showsRecommendedSection)
            }
            header: {
                Text("Start Menu")
            }
        }
        .formStyle(.grouped)
        .padding(.horizontal, 24)
        .padding(.vertical, 18)
    }
}

private struct ApplicationSettingsPane: View {
    @ObservedObject var model: StartMenuModel

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
                    model.pinnedApplicationIDs.removeAll()
                    StartMenuStorage().savePinnedIDs([])
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

import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: StartMenuModel

    var body: some View {
        Form {
            Section("Shortcut") {
                Picker("Show iStart", selection: hotKeySelection) {
                    ForEach(HotKey.all) { hotKey in
                        Text(verbatim: hotKey.localizedTitle).tag(hotKey.rawValue)
                    }
                }

                Text(model.hotKeyRegistrationStatus.message)
                    .font(.caption)
                    .foregroundStyle(model.hotKeyRegistrationStatus == .registered ? Color.secondary : Color.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Section("Applications") {
                Toggle("Show recommended section", isOn: $model.showsRecommendedSection)

                HStack {
                    Text(String.localizedStringWithFormat(String(localized: "%lld apps indexed"), model.applications.count))
                    Spacer()
                    Button("Reload") {
                        model.reloadApplicationsInBackground()
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Additional application folders")
                        Spacer()
                        Button("Add Folder") {
                            model.addApplicationSearchDirectory()
                        }
                    }

                    if model.applicationSearchDirectories.isEmpty {
                        Text("Add your user Applications folder to index Chrome PWA apps in sandbox mode.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        ForEach(model.applicationSearchDirectories, id: \.standardizedFileURL) { directory in
                            HStack(spacing: 8) {
                                Image(systemName: "folder")
                                    .foregroundStyle(.secondary)
                                Text(verbatim: directory.path)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                Spacer()
                                Button {
                                    model.removeApplicationSearchDirectory(directory)
                                } label: {
                                    Image(systemName: "minus.circle")
                                }
                                .buttonStyle(.borderless)
                                .help(Text("Remove Folder"))
                            }
                        }
                    }
                }

                Button("Clear pinned apps") {
                    model.pinnedApplicationIDs.removeAll()
                    StartMenuStorage().savePinnedIDs([])
                }
            }
        }
        .formStyle(.grouped)
        .padding(20)
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

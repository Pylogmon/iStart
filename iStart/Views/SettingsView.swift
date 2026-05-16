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

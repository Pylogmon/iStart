import AppKit
import SwiftUI

struct StartMenuView: View {
    @ObservedObject var model: StartMenuModel
    @State private var showsAllApps = false
    @Environment(\.openSettings) private var openSettings
    @FocusState private var searchFocused: Bool

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 6)

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 18) {
                searchField

                if model.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    if showsAllApps {
                        allAppsSection
                    } else {
                        pinnedSection
                        recommendedSection
                    }
                } else {
                    searchResultsSection
                }
            }
            .padding(.horizontal, 34)
            .padding(.top, 28)
            .padding(.bottom, 18)

            Spacer(minLength: 0)
            footer
        }
        .frame(minWidth: 560, minHeight: 620)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.white.opacity(0.22), lineWidth: 1)
        }
        .onAppear {
            model.focusSearch()
        }
        .onChange(of: model.searchFocusToken) {
            searchFocused = true
        }
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.secondary)

            TextField(String(localized: "Search for apps, settings, and documents"), text: $model.searchText)
                .textFieldStyle(.plain)
                .focused($searchFocused)
                .font(.system(size: 15))
                .onSubmit {
                    if let first = model.filteredApplications.first {
                        launch(first)
                    }
                }
        }
        .padding(.horizontal, 16)
        .frame(height: 44)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.accentColor.opacity(searchFocused ? 0.7 : 0.18), lineWidth: searchFocused ? 1.5 : 1)
        }
    }

    private var pinnedSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(title: String(localized: "Pinned"), trailing: String(localized: "All apps")) {
                showsAllApps = true
            }

            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(model.pinnedApplications.prefix(18)) { application in
                    ApplicationTile(application: application, isPinned: model.isPinned(application)) {
                        launch(application)
                    } onTogglePinned: {
                        model.togglePinned(application)
                    }
                }
            }
        }
    }

    private var recommendedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: String(localized: "Recommended"), trailing: String(localized: "More"))

            if let launchError = model.launchError {
                Label(launchError, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

            if model.recentApplications.isEmpty {
                ContentUnavailableView(
                    String(localized: "No recent apps"),
                    systemImage: "clock",
                    description: Text("Launched apps will appear here.")
                )
                .frame(maxWidth: .infinity, minHeight: 118)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(model.recentApplications.prefix(6)) { application in
                        RecentApplicationRow(application: application) {
                            launch(application)
                        }
                    }
                }
            }
        }
    }

    private var searchResultsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: String(localized: "Best match"), trailing: String.localizedStringWithFormat(String(localized: "%lld results"), model.filteredApplications.count))

            ScrollView {
                LazyVStack(spacing: 6) {
                    ForEach(model.filteredApplications.prefix(80)) { application in
                        SearchResultRow(application: application, isPinned: model.isPinned(application)) {
                            launch(application)
                        } onTogglePinned: {
                            model.togglePinned(application)
                        }
                    }
                }
                .padding(.vertical, 2)
            }
            .frame(maxHeight: 565)
        }
    }

    private var allAppsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: String(localized: "All apps"), trailing: String(localized: "Back")) {
                showsAllApps = false
            }

            ScrollView {
                LazyVStack(spacing: 6) {
                    ForEach(model.applications) { application in
                        SearchResultRow(application: application, isPinned: model.isPinned(application)) {
                            launch(application)
                        } onTogglePinned: {
                            model.togglePinned(application)
                        }
                    }
                }
                .padding(.vertical, 2)
            }
            .frame(maxHeight: 620)
        }
    }

    private var footer: some View {
        HStack {
            AccountButton()

            Spacer()

            Button {
                NotificationCenter.default.post(name: .startMenuShouldHide, object: nil)
                NSApp.activate(ignoringOtherApps: true)
                openSettings()
            } label: {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.plain)
            .help("Settings")
        }
        .padding(.horizontal, 32)
        .frame(height: 64)
        .background(.regularMaterial)
    }

    private func sectionHeader(title: String, trailing: String, action: (() -> Void)? = nil) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 14, weight: .semibold))

            Spacer()

            if let action {
                Button(action: action) {
                    Text(trailing)
                        .font(.system(size: 12, weight: .medium))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(.thinMaterial, in: Capsule())
                }
                .buttonStyle(.plain)
            } else {
                Text(trailing)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(.thinMaterial, in: Capsule())
            }
        }
    }

    private func launch(_ application: InstalledApplication) {
        model.launch(application)
    }
}

import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct StartMenuView: View {
    @ObservedObject var model: StartMenuModel
    @State private var showsAllApps = false
    @State private var draggedPinnedApplication: InstalledApplication?
    @State private var selectedSearchResultID: String?
    @Environment(\.openSettings) private var openSettings
    @FocusState private var searchFocused: Bool

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 6)
    private var searchResults: [InstalledApplication] {
        Array(model.filteredApplications.prefix(80))
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 18) {
                searchField

                if model.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    if showsAllApps {
                        allAppsSection
                    } else {
                        pinnedSection
                        if model.showsRecommendedSection {
                            recommendedSection
                        }
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
        .onChange(of: model.searchText) {
            selectFirstSearchResult()
        }
        .onChange(of: model.applications) {
            validateSelectedSearchResult()
        }
        .onReceive(NotificationCenter.default.publisher(for: .startMenuMoveSelectionDown)) { _ in
            moveSearchSelection(by: 1)
        }
        .onReceive(NotificationCenter.default.publisher(for: .startMenuMoveSelectionUp)) { _ in
            moveSearchSelection(by: -1)
        }
        .onReceive(NotificationCenter.default.publisher(for: .startMenuOpenSelection)) { _ in
            openSelectedSearchResult()
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
                    openSelectedSearchResult()
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

            ScrollView {
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(model.pinnedApplications.prefix(pinnedApplicationLimit)) { application in
                        ApplicationTile(application: application, isPinned: model.isPinned(application)) {
                            launch(application)
                        } onTogglePinned: {
                            model.togglePinned(application)
                        }
                        .opacity(draggedPinnedApplication?.id == application.id ? 0.45 : 1)
                        .onDrag {
                            draggedPinnedApplication = application
                            return NSItemProvider(object: application.id as NSString)
                        }
                        .onDrop(
                            of: [.text],
                            delegate: PinnedApplicationDropDelegate(
                                destination: application,
                                draggedApplication: $draggedPinnedApplication,
                                model: model
                            )
                        )
                    }
                }
                .padding(.vertical, 2)
            }
            .scrollIndicators(model.showsRecommendedSection ? .hidden : .automatic)
            .frame(maxHeight: model.showsRecommendedSection ? 320 : 622)
        }
    }

    private var pinnedApplicationLimit: Int {
        model.showsRecommendedSection ? 18 : 36
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

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(searchResults) { application in
                            SearchResultRow(
                                application: application,
                                isPinned: model.isPinned(application),
                                isSelected: selectedSearchResultID == application.id
                            ) {
                                launch(application)
                            } onTogglePinned: {
                                model.togglePinned(application)
                            }
                            .id(application.id)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .frame(maxHeight: 565)
                .onChange(of: selectedSearchResultID) {
                    guard let selectedSearchResultID else { return }
                    withAnimation(.easeInOut(duration: 0.12)) {
                        proxy.scrollTo(selectedSearchResultID, anchor: .center)
                    }
                }
            }
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
                        SearchResultRow(application: application, isPinned: model.isPinned(application), isSelected: false) {
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

    private func selectFirstSearchResult() {
        guard isSearching else {
            selectedSearchResultID = nil
            return
        }

        selectedSearchResultID = searchResults.first?.id
    }

    private func validateSelectedSearchResult() {
        guard isSearching else {
            selectedSearchResultID = nil
            return
        }

        if let selectedSearchResultID,
           searchResults.contains(where: { $0.id == selectedSearchResultID }) {
            return
        }

        selectedSearchResultID = searchResults.first?.id
    }

    private func moveSearchSelection(by offset: Int) {
        guard isSearching, !searchResults.isEmpty else { return }

        guard let currentID = selectedSearchResultID,
              let currentIndex = searchResults.firstIndex(where: { $0.id == currentID })
        else {
            selectedSearchResultID = searchResults.first?.id
            return
        }

        let nextIndex = min(max(currentIndex + offset, 0), searchResults.count - 1)
        selectedSearchResultID = searchResults[nextIndex].id
    }

    private func openSelectedSearchResult() {
        guard isSearching else { return }

        guard let application = selectedSearchResultID.flatMap(applicationForSearchResultID) ?? searchResults.first else {
            return
        }

        launch(application)
    }

    private func applicationForSearchResultID(_ id: String) -> InstalledApplication? {
        searchResults.first { $0.id == id }
    }

    private var isSearching: Bool {
        !model.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

private struct PinnedApplicationDropDelegate: DropDelegate {
    let destination: InstalledApplication
    @Binding var draggedApplication: InstalledApplication?
    let model: StartMenuModel

    func dropEntered(info: DropInfo) {
        guard let draggedApplication, draggedApplication.id != destination.id else { return }

        withAnimation(.easeInOut(duration: 0.12)) {
            model.movePinnedApplication(draggedApplication, toPositionOf: destination)
        }
    }

    func performDrop(info: DropInfo) -> Bool {
        draggedApplication = nil
        return true
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }
}

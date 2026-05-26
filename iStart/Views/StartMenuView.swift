import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct StartMenuView: View {
    @ObservedObject var model: StartMenuModel
    var onOpenSettings: () -> Void = {}
    @State private var isPinnedExpanded = false
    @State private var isRecommendedExpanded = false
    @State private var allAppsDisplayMode = AllAppsDisplayMode.categories
    @State private var selectedCategory: ApplicationCategory?
    @State private var draggedPinnedApplication: InstalledApplication?
    @State private var selectedSearchResultID: String?
    @FocusState private var searchFocused: Bool

    private let pinnedCollapsedLimit = 12
    private let recommendedCollapsedLimit = 2
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 6)
    private let categoryColumns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 4)
    private var searchResults: [InstalledApplication] {
        Array(model.filteredApplications.prefix(80))
    }
    private var allAppCategories: [ApplicationCategory] {
        Dictionary(grouping: model.applications) { application in
            Self.normalizedCategoryIdentifier(for: application.categoryIdentifier)
        }
        .map { identifier, applications in
            ApplicationCategory(
                id: identifier,
                title: Self.categoryTitle(for: identifier),
                applications: applications.sorted {
                    $0.name.localizedStandardCompare($1.name) == .orderedAscending
                }
            )
        }
        .sorted { lhs, rhs in
            let titleComparison = lhs.title.localizedStandardCompare(rhs.title)
            if titleComparison != .orderedSame {
                return titleComparison == .orderedAscending
            }

            return lhs.id < rhs.id
        }
    }
    private var visiblePinnedApplications: [InstalledApplication] {
        if isPinnedExpanded {
            return model.pinnedApplications
        }

        return Array(model.pinnedApplications.prefix(pinnedCollapsedLimit))
    }
    private var visibleRecentApplications: [InstalledApplication] {
        if isRecommendedExpanded {
            return model.recentApplications
        }

        return Array(model.recentApplications.prefix(recommendedCollapsedLimit))
    }
    private var recommendedGridHeight: CGFloat {
        let rowCount = max(1, (visibleRecentApplications.count + 1) / 2)
        return CGFloat(rowCount * 62 + max(0, rowCount - 1) * 10)
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                searchField
            }
            .padding(.horizontal, 34)
            .padding(.top, 28)
            .padding(.bottom, 18)

            Group {
                if isSearching {
                    searchResultsSection
                } else {
                    homeSection
                }
            }
            .padding(.horizontal, 34)
            .padding(.bottom, 18)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            footer
        }
        .frame(minWidth: 560, minHeight: 620)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.white.opacity(0.22), lineWidth: 1)
        }
        .overlay {
            if let selectedCategory {
                categoryFolderOverlay(for: selectedCategory)
            }
        }
        .onAppear {
            model.focusSearch()
        }
        .onChange(of: model.homeResetToken) {
            isPinnedExpanded = false
            isRecommendedExpanded = false
            selectedCategory = nil
            selectedSearchResultID = nil
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

    private var homeSection: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                pinnedSection

                if model.showsRecommendedSection {
                    recommendedSection
                }

                allAppsSection
            }
            .padding(.vertical, 2)
        }
        .scrollIndicators(.automatic)
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.secondary)

            TextField(String(localized: "Search for apps"), text: $model.searchText)
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
            sectionHeader(
                title: String(localized: "Pinned"),
                trailing: model.pinnedApplications.count > pinnedCollapsedLimit
                    ? String(localized: isPinnedExpanded ? "Collapse" : "Expand")
                    : nil
            ) {
                withAnimation(.easeInOut(duration: 0.16)) {
                    isPinnedExpanded.toggle()
                }
            }

            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(visiblePinnedApplications) { application in
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
        }
    }

    private var recommendedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(
                title: String(localized: "Recommended"),
                trailing: model.recentApplications.count > recommendedCollapsedLimit
                    ? String(localized: isRecommendedExpanded ? "Collapse" : "Expand")
                    : nil
            ) {
                withAnimation(.easeInOut(duration: 0.16)) {
                    isRecommendedExpanded.toggle()
                }
            }

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
                GeometryReader { proxy in
                    let columnSpacing: CGFloat = 8
                    let columnWidth = max((proxy.size.width - columnSpacing * 5) / 6, 0)
                    let groupWidth = columnWidth * 3 + columnSpacing * 2
                    let iconLeadingPadding = max((columnWidth - 42) / 2, 0)

                    LazyVGrid(
                        columns: [
                            GridItem(.fixed(groupWidth), spacing: columnSpacing),
                            GridItem(.fixed(groupWidth), spacing: 0)
                        ],
                        spacing: 10
                    ) {
                        ForEach(visibleRecentApplications) { application in
                            recommendedApplicationRow(
                                application: application,
                                iconLeadingPadding: iconLeadingPadding
                            )
                        }
                    }
                }
                .frame(height: recommendedGridHeight)
            }
        }
    }

    private func recommendedApplicationRow(
        application: InstalledApplication,
        iconLeadingPadding: CGFloat
    ) -> some View {
        Button {
            launch(application)
        } label: {
            HStack(spacing: 10) {
                AppIcon(path: application.path, size: 42)

                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: application.name)
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)

                    Text("Recently opened")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding(.leading, iconLeadingPadding)
            .padding(.trailing, 12)
            .frame(height: 62)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
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
                .scrollIndicators(.automatic)
                .onChange(of: selectedSearchResultID) {
                    guard let selectedSearchResultID else { return }
                    withAnimation(.easeInOut(duration: 0.12)) {
                        proxy.scrollTo(selectedSearchResultID, anchor: .center)
                    }
                }
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private var allAppsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            allAppsHeader

            switch allAppsDisplayMode {
            case .categories:
                LazyVGrid(columns: categoryColumns, spacing: 12) {
                    ForEach(allAppCategories) { category in
                        ApplicationCategoryCard(category: category) { application in
                            launch(application)
                        } onOpenCategory: {
                            withAnimation(.easeInOut(duration: 0.16)) {
                                selectedCategory = category
                            }
                        }
                    }
                }
            case .list:
                LazyVStack(spacing: 6) {
                    ForEach(model.applications) { application in
                        SearchResultRow(application: application, isPinned: model.isPinned(application), isSelected: false) {
                            launch(application)
                        } onTogglePinned: {
                            model.togglePinned(application)
                        }
                    }
                }
            }
        }
    }

    private func categoryFolderOverlay(for category: ApplicationCategory) -> some View {
        ZStack {
            Color.black.opacity(0.18)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.16)) {
                        selectedCategory = nil
                    }
                }

            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text(category.title)
                        .font(.system(size: 18, weight: .semibold))
                        .lineLimit(1)

                    Spacer()

                    Button {
                        withAnimation(.easeInOut(duration: 0.16)) {
                            selectedCategory = nil
                        }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .bold))
                            .frame(width: 24, height: 24)
                            .background(.thinMaterial, in: Circle())
                    }
                    .buttonStyle(.plain)
                }

                ScrollView {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 14) {
                        ForEach(category.applications) { application in
                            Button {
                                launch(application)
                            } label: {
                                VStack(spacing: 7) {
                                    AppIcon(path: application.path, size: 42)

                                    Text(verbatim: application.name)
                                        .font(.system(size: 11, weight: .medium))
                                        .lineLimit(2)
                                        .multilineTextAlignment(.center)
                                        .frame(height: 28, alignment: .top)
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 82)
                                .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .frame(maxHeight: 330)
            }
            .padding(20)
            .frame(width: 430)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(.white.opacity(0.18), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.22), radius: 32, y: 16)
        }
    }

    private var allAppsHeader: some View {
        HStack {
            Text(String(localized: "All apps"))
                .font(.system(size: 14, weight: .semibold))

            Text(String.localizedStringWithFormat(String(localized: "%lld apps"), model.applications.count))
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)

            Spacer()

            Menu {
                ForEach(AllAppsDisplayMode.allCases) { mode in
                    Button {
                        allAppsDisplayMode = mode
                    } label: {
                        Label(mode.title, systemImage: allAppsDisplayMode == mode ? "checkmark" : mode.systemImage)
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: allAppsDisplayMode.systemImage)
                    Text(allAppsDisplayMode.title)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .bold))
                }
                .font(.system(size: 12, weight: .medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(.thinMaterial, in: Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    private var footer: some View {
        HStack {
            AccountButton()

            Spacer()

            Button {
                NotificationCenter.default.post(name: .startMenuShouldHide, object: nil)
                DispatchQueue.main.async {
                    onOpenSettings()
                }
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

    private func sectionHeader(title: String, trailing: String? = nil, action: (() -> Void)? = nil) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 14, weight: .semibold))

            Spacer()

            if let action, let trailing {
                Button(action: action) {
                    Text(trailing)
                        .font(.system(size: 12, weight: .medium))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(.thinMaterial, in: Capsule())
                }
                .buttonStyle(.plain)
            } else if let trailing {
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

        selectedCategory = nil
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

    private static func categoryTitle(for identifier: String) -> String {
        switch identifier {
        case "public.app-category.business":
            return String(localized: "Business")
        case "public.app-category.developer-tools":
            return String(localized: "Developer Tools")
        case "public.app-category.education":
            return String(localized: "Education")
        case "public.app-category.entertainment":
            return String(localized: "Entertainment")
        case "public.app-category.finance":
            return String(localized: "Finance")
        case "public.app-category.games":
            return String(localized: "Games")
        case "public.app-category.graphics-design":
            return String(localized: "Graphics & Design")
        case "public.app-category.healthcare-fitness":
            return String(localized: "Health & Fitness")
        case "public.app-category.lifestyle":
            return String(localized: "Lifestyle")
        case "public.app-category.medical":
            return String(localized: "Medical")
        case "public.app-category.music":
            return String(localized: "Music")
        case "public.app-category.news":
            return String(localized: "News")
        case "public.app-category.photography":
            return String(localized: "Photography")
        case "public.app-category.productivity":
            return String(localized: "Productivity")
        case "public.app-category.reference":
            return String(localized: "Reference")
        case "public.app-category.social-networking":
            return String(localized: "Social Networking")
        case "public.app-category.sports":
            return String(localized: "Sports")
        case "public.app-category.travel":
            return String(localized: "Travel")
        case "public.app-category.utilities":
            return String(localized: "Utilities")
        case "public.app-category.video":
            return String(localized: "Video")
        default:
            return String(localized: "Other")
        }
    }

    private static func normalizedCategoryIdentifier(for identifier: String?) -> String {
        guard let identifier, knownCategoryIdentifiers.contains(identifier) else {
            return ApplicationCategory.otherID
        }

        return identifier
    }

    private static let knownCategoryIdentifiers: Set<String> = [
        "public.app-category.business",
        "public.app-category.developer-tools",
        "public.app-category.education",
        "public.app-category.entertainment",
        "public.app-category.finance",
        "public.app-category.games",
        "public.app-category.graphics-design",
        "public.app-category.healthcare-fitness",
        "public.app-category.lifestyle",
        "public.app-category.medical",
        "public.app-category.music",
        "public.app-category.news",
        "public.app-category.photography",
        "public.app-category.productivity",
        "public.app-category.reference",
        "public.app-category.social-networking",
        "public.app-category.sports",
        "public.app-category.travel",
        "public.app-category.utilities",
        "public.app-category.video"
    ]
}

private enum AllAppsDisplayMode: String, CaseIterable, Identifiable {
    case categories
    case list

    var id: String { rawValue }

    var title: String {
        switch self {
        case .categories:
            return String(localized: "Categories")
        case .list:
            return String(localized: "List")
        }
    }

    var systemImage: String {
        switch self {
        case .categories:
            return "square.grid.2x2"
        case .list:
            return "list.bullet"
        }
    }
}

private struct ApplicationCategory: Identifiable {
    static let otherID = "istart.other"

    let id: String
    let title: String
    let applications: [InstalledApplication]
}

private struct ApplicationCategoryCard: View {
    let category: ApplicationCategory
    let onLaunch: (InstalledApplication) -> Void
    let onOpenCategory: () -> Void

    private var visibleDirectApplications: [InstalledApplication] {
        if category.applications.count > 4 {
            return Array(category.applications.prefix(3))
        }

        return Array(category.applications.prefix(4))
    }

    private var stackedApplications: [InstalledApplication] {
        Array(category.applications.dropFirst(3).prefix(3))
    }

    var body: some View {
        VStack(spacing: 7) {
            LazyVGrid(
                columns: Array(repeating: GridItem(.fixed(42), spacing: 8), count: 2),
                spacing: 8
            ) {
                ForEach(visibleDirectApplications) { application in
                    Button {
                        onLaunch(application)
                    } label: {
                        AppIcon(path: application.path, size: 42)
                            .frame(width: 42, height: 42)
                    }
                    .buttonStyle(.plain)
                }

                if category.applications.count > 4 {
                    Button(action: onOpenCategory) {
                        ApplicationIconStack(applications: stackedApplications)
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(width: 92, height: 92, alignment: .topLeading)
            .frame(width: 110, height: 110, alignment: .center)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(.white.opacity(0.12), lineWidth: 1)
            }

            Text(category.title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.primary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct ApplicationIconStack: View {
    let applications: [InstalledApplication]

    private let offsets = [
        CGSize(width: -8, height: 8),
        CGSize(width: 2, height: 2),
        CGSize(width: 9, height: -6),
        CGSize(width: -2, height: -11)
    ]

    var body: some View {
        ZStack {
            ForEach(Array(applications.enumerated()), id: \.element.id) { index, application in
                AppIcon(path: application.path, size: 42)
                    .frame(width: 42, height: 42)
                    .offset(index < offsets.count ? offsets[index] : .zero)
            }
        }
        .frame(width: 42, height: 42)
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

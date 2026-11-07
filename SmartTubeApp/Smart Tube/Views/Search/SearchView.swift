import SmartTubeCore
import SwiftUI

// MARK: - SearchView
//
// Search interface with live suggestions and paginated results.
// Mirrors the Android `SearchTagsActivity`.

struct SearchView: View {
    @Environment(SearchViewModel.self) private var vm
    @Environment(AppNavigator.self) private var navigator
    @Environment(SettingsStore.self) private var store
    @State private var showFilterSheet = false

    init() {}

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                searchBar
                if vm.query.isEmpty {
                    idleView
                } else if vm.isLoading || vm.isAwaitingSearch || !vm.results.isEmpty {
                    resultsView
                } else {
                    noResultsView
                }
            }
        }
        .scrollClipDisabled()
        .toolbar(.hidden, for: .navigationBar)
        .task(id: vm.query) { await vm.searchAsYouType() }
        .fullScreenCover(isPresented: $showFilterSheet) {
            SearchFilterSheet(current: vm.filter) { newFilter in
                vm.applyFilter(newFilter)
            }
        }
    }

    // MARK: - Search bar

    /// A text field rather than `.searchable`: Select on a letter of `.searchable`'s inline keyboard
    /// moved focus to the first control below it. A text field opens the full-screen system keyboard.
    private var searchBar: some View {
        @Bindable var vm = vm
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                TextField("Search YouTube", text: $vm.query)
                    .autocorrectionDisabled()
                    .frame(width: 900)
                    .onSubmit {
                        if vm.isAwaitingSearch {
                            vm.search()
                        } else {
                            Task { await vm.recordCurrentSearch() }
                        }
                    }
                    .accessibilityIdentifier("search.field")
                Button {
                    showFilterSheet = true
                } label: {
                    Label("Search filters", systemImage: filterSymbol)
                }
                .accessibilityIdentifier("search.filterButton")
                activeFilterChips
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
        .scrollClipDisabled()
        .focusSection()
    }

    // MARK: - Idle content (recent + recommended searches)

    private var idleView: some View {
        VStack(alignment: .leading, spacing: 32) {
            if !vm.history.isEmpty {
                querySection("Recent") {
                    ForEach(vm.history) { entry in
                        queryButton(entry.query, systemImage: AppSymbol.clock)
                            .accessibilityIdentifier("search.history.\(entry.query)")
                    }
                    Button("Clear History", role: .destructive) {
                        vm.clearHistory()
                    }
                    .accessibilityIdentifier("search.history.clearAll")
                }
            }
            querySection("Recommended") {
                ForEach(vm.suggestions, id: \.self) { suggestion in
                    queryButton(suggestion, systemImage: AppSymbol.search)
                }
            }
        }
        .padding(.horizontal)
        .focusSection()
        .accessibilityIdentifier("search.suggestionsContainer")
    }

    private func querySection<Content: View>(
        _ title: LocalizedStringKey, @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.secondary)
            content()
        }
    }

    private func queryButton(_ query: String, systemImage: String) -> some View {
        Button {
            vm.query = query
            vm.search()
        } label: {
            Label(query, systemImage: systemImage)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Active filter chips

    private var filterSymbol: String {
        vm.filter.isDefault ? AppSymbol.filter : AppSymbol.filterActive
    }

    @ViewBuilder
    private var activeFilterChips: some View {
        if vm.filter.sortOrder != .relevance {
            FilterChip(label: LocalizedStringKey(vm.filter.sortOrder.label)) {
                var f = vm.filter
                f.sortOrder = .relevance
                vm.applyFilter(f)
            }
        }
        if vm.filter.uploadDate != .anytime {
            FilterChip(label: LocalizedStringKey(vm.filter.uploadDate.label)) {
                var f = vm.filter
                f.uploadDate = .anytime
                vm.applyFilter(f)
            }
        }
        if vm.filter.type != .any {
            FilterChip(label: LocalizedStringKey(vm.filter.type.label)) {
                var f = vm.filter
                f.type = .any
                vm.applyFilter(f)
            }
        }
        if vm.filter.duration != .any {
            FilterChip(label: LocalizedStringKey(vm.filter.duration.label)) {
                var f = vm.filter
                f.duration = .any
                vm.applyFilter(f)
            }
        }
    }

    // MARK: - Results

    private var resultsView: some View {
        let hideVideoPremieres = store.settings.hideVideoPremieres
        let displayResults = vm.results
            .filter { !$0.isShort }
            .filter { !hideVideoPremieres || !$0.isUpcoming }
        return VStack {
            if (vm.isLoading || vm.isAwaitingSearch) && vm.results.isEmpty {
                ProgressView().frame(maxWidth: .infinity).padding()
            }
            VideoGridSection(
                videos: displayResults,
                onSelect: { video in
                    let captured = displayResults
                    Task { @MainActor in
                        await vm.recordCurrentSearch()
                        await CurrentQueueStore.shared.replaceAll(with: captured)
                        let startIdx = captured.firstIndex(where: { $0.id == video.id }) ?? 0
                        let toPlay = await CurrentQueueStore.shared.videoAt(index: startIdx) ?? video
                        navigator.play(toPlay)
                    }
                },
                loadMore: vm.loadMore
            )
            if vm.isLoading && !vm.results.isEmpty {
                ProgressView().frame(maxWidth: .infinity).padding()
            }
        }
        .accessibilityIdentifier("search.results")
    }

    private var placeholderView: some View {
        VStack(spacing: 16) {
            Image(systemName: AppSymbol.search)
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            Text("Search for videos, channels & playlists")
                .font(.headline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var noResultsView: some View {
        VStack(spacing: 16) {
            Image(systemName: AppSymbol.questionCircle)
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            Text("No results for \"\(vm.query)\"")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }
}

// MARK: - FilterChip

private struct FilterChip: View {
    let label: LocalizedStringKey
    let onRemove: () -> Void

    var body: some View {
        // A single focusable button: the Siri Remote can't reach a tiny inner target.
        Button(action: onRemove) {
            Label {
                Text(label)
            } icon: {
                Image(systemName: AppSymbol.xmark)
            }
        }
    }
}

// MARK: - SearchFilterSheet

struct SearchFilterSheet: View {
    let current: SearchFilter
    let onApply: (SearchFilter) -> Void

    @State private var draft: SearchFilter
    @Environment(\.dismiss) private var dismiss

    init(current: SearchFilter, onApply: @escaping (SearchFilter) -> Void) {
        self.current = current
        self.onApply = onApply
        _draft = State(initialValue: current)
    }

    var body: some View {
        NavigationStack {
            SettingsPageLayout {
                Form {
                    Section {
                        SettingsPicker("Sort by", selection: $draft.sortOrder) {
                            ForEach(SearchFilter.SortOrder.allCases, id: \.self) { order in
                                Text(LocalizedStringKey(order.label)).tag(order)
                            }
                        }
                        SettingsPicker("Upload date", selection: $draft.uploadDate) {
                            ForEach(SearchFilter.UploadDate.allCases, id: \.self) { date in
                                Text(LocalizedStringKey(date.label)).tag(date)
                            }
                        }
                        SettingsPicker("search.filter.type", selection: $draft.type) {
                            ForEach(SearchFilter.VideoType.allCases, id: \.self) { type in
                                Text(LocalizedStringKey(type.label)).tag(type)
                            }
                        }
                        SettingsPicker("Duration", selection: $draft.duration) {
                            ForEach(SearchFilter.Duration.allCases, id: \.self) { dur in
                                Text(LocalizedStringKey(dur.label)).tag(dur)
                            }
                        }
                    }
                    Section {
                        Button("Apply") {
                            onApply(draft)
                            dismiss()
                        }
                        .accessibilityIdentifier("search.filterApplyButton")
                        Button("Cancel", role: .cancel) { dismiss() }
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .accessibilityIdentifier("search.filterSheet")
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Idle – With history") {
    NavigationStack { SearchView() }
        .previewEnvironment()
}
#Preview("Results") {
    NavigationStack { SearchView() }
        .environment(SearchViewModel.preview(query: "open movies"))
        .previewEnvironment()
}
#Preview("Loading") {
    NavigationStack { SearchView() }
        .environment(SearchViewModel.preview(query: "open movies", hangs: true))
        .previewEnvironment()
}
#Preview("No results") {
    NavigationStack { SearchView() }
        .environment(SearchViewModel.preview(query: "zzzzzz", results: []))
        .previewEnvironment()
}
#Preview("Filter sheet") {
    SearchFilterSheet(current: .default) { _ in }
        .previewEnvironment()
}
#endif

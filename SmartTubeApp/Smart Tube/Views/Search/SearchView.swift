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
        @Bindable var vm = vm
        // Everything is in one scroll view with `.searchable` on it, as in Apple's tvOS search sample,
        // so focus can move between the search field, the filters and the results.
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                tvFilterRow
                if vm.query.isEmpty {
                    tvIdleView
                } else if vm.isLoading || vm.isAwaitingSearch || !vm.results.isEmpty {
                    resultsView
                } else {
                    noResultsView
                }
            }
        }
        .scrollClipDisabled()
        // The system search UI (field and keyboard) lives in the navigation bar, so unlike
        // the other tabs this screen must not hide it.
        .searchable(text: $vm.query, prompt: "Search YouTube")
        .autocorrectionDisabled()
        .searchSuggestions {
            if vm.query.isEmpty {
                ForEach(vm.history) { entry in
                    Label(entry.query, systemImage: AppSymbol.clock).searchCompletion(entry.query)
                }
            }
            ForEach(suggestionsWithoutHistory, id: \.self) { suggestion in
                Label(suggestion, systemImage: AppSymbol.search).searchCompletion(suggestion)
            }
        }
        .onSubmit(of: .search) {
            if vm.isAwaitingSearch {
                vm.search()
            } else {
                Task { await vm.recordCurrentSearch() }
            }
        }
        .task(id: vm.query) { await vm.searchAsYouType() }
        .sheet(isPresented: $showFilterSheet) {
            SearchFilterSheet(current: vm.filter) { newFilter in
                vm.applyFilter(newFilter)
            }
        }
        .task(id: vm.query) { await vm.updateSuggestions(for: vm.query) }
    }

    // MARK: - tvOS filter row

    private var tvFilterRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                Button {
                    showFilterSheet = true
                } label: {
                    Label("Search filters", systemImage: filterSymbol)
                }
                .accessibilityIdentifier("search.filterButton")
                activeFilterChips
            }
            .padding(.vertical, 12)
        }
        .scrollClipDisabled()
        .focusSection()
    }

    // MARK: - Idle content

    /// Has nothing focusable besides clearing the history. Recent and recommended searches are
    /// search suggestions, because a list of buttons here took focus from the system keyboard.
    private var tvIdleView: some View {
        VStack(spacing: 24) {
            ContentUnavailableView("Search YouTube", systemImage: AppSymbol.search)
            if !vm.history.isEmpty {
                Button("Clear History", role: .destructive) {
                    vm.clearHistory()
                }
                .accessibilityIdentifier("search.history.clearAll")
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
        .accessibilityIdentifier("search.suggestionsContainer")
    }

    /// The idle screen also lists the history, which can contain the same terms.
    private var suggestionsWithoutHistory: [String] {
        guard vm.query.isEmpty else { return vm.suggestions }
        let history = Set(vm.history.map(\.query))
        return vm.suggestions.filter { !history.contains($0) }
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
            // A plain stack rather than a Form, whose rows fill the overlay and ignore content margins.
            // Focused rows grow, so they need room around them.
            ScrollView {
                VStack(spacing: 20) {
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
                    // Rows, because two toolbar buttons overlap in a tvOS sheet.
                    Button {
                        onApply(draft)
                        dismiss()
                    } label: {
                        Text("Apply").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.top, 20)
                    .accessibilityIdentifier("search.filterApplyButton")
                    Button(role: .cancel) {
                        dismiss()
                    } label: {
                        Text("Cancel").frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, 60)
                .padding(.vertical, 24)
            }
            .scrollClipDisabled()
            .navigationTitle("Search filters")
        }
        // On the stack, because pushed pages don't inherit from the view that pushed them.
        .environment(\.settingsOptionsUsePageLayout, false)
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

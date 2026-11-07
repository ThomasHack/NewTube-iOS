import SmartTubeIOSCore
import SwiftUI

// MARK: - SearchView
//
// Search interface with live suggestions and paginated results.
// Mirrors the Android `SearchTagsActivity`.

public struct SearchView: View {
    @Environment(SearchViewModel.self) private var vm
    @Environment(\.innerTubeAPI) private var api
    @Environment(SettingsStore.self) private var store
    @State private var selectedVideo: Video?
    @State private var channelDestination: ChannelDestination?
    @State private var showFilterSheet = false

    public init() {}

    public var body: some View {
        @Bindable var vm = vm
        VStack(spacing: 0) {
            if !vm.query.isEmpty {
                tvFilterRow
            }
            Group {
                if vm.query.isEmpty {
                    tvIdleView
                } else if vm.isLoading || vm.isAwaitingSearch || !vm.results.isEmpty {
                    resultsView
                } else {
                    noResultsView
                }
            }
        }
        // The system search UI (field and keyboard) lives in the navigation bar, so unlike
        // the other tabs this screen must not hide it.
        .searchable(text: $vm.query, prompt: "Search YouTube")
        .autocorrectionDisabled()
        .searchSuggestions {
            if !vm.query.isEmpty {
                ForEach(vm.suggestions, id: \.self) { suggestion in
                    Text(suggestion).searchCompletion(suggestion)
                }
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
        .navigationDestination(item: $selectedVideo) { video in
            PlayerView(video: video, api: api)
        }
        .navigationDestination(item: $channelDestination) { dest in
            ChannelView(channelId: dest.channelId)
        }
        .onReceive(NotificationCenter.default.publisher(for: .openChannel)) { note in
            guard let channelId = note.userInfo?["channelId"] as? String, !channelId.isEmpty else { return }
            channelDestination = ChannelDestination(channelId: channelId)
        }
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

    // MARK: - tvOS idle content (recent + recommended searches)

    private var tvIdleView: some View {
        List {
            if !vm.history.isEmpty {
                Section("Recent") {
                    ForEach(vm.history) { entry in
                        tvQueryButton(entry.query, systemImage: AppSymbol.clock)
                            .accessibilityIdentifier("search.history.\(entry.query)")
                    }
                    Button("Clear History", role: .destructive) {
                        vm.clearHistory()
                    }
                    .accessibilityIdentifier("search.history.clearAll")
                }
            }
            Section("Recommended") {
                ForEach(vm.suggestions, id: \.self) { suggestion in
                    tvQueryButton(suggestion, systemImage: AppSymbol.search)
                }
            }
        }
        .accessibilityIdentifier("search.suggestionsContainer")
    }

    private func tvQueryButton(_ query: String, systemImage: String) -> some View {
        Button {
            vm.query = query
            vm.search()
        } label: {
            Label(query, systemImage: systemImage)
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
        let hideShorts = store.settings.hideShorts
        let hideLiveShorts = store.settings.hideLiveShorts
        let hideVideoPremieres = store.settings.hideVideoPremieres
        let displayResults = vm.results
            .filter { !hideShorts || !$0.isShort }
            .filter { !hideLiveShorts || !($0.isLive && $0.isShort) }
            .filter { !hideVideoPremieres || !$0.isUpcoming }
        return ScrollView {
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
                        selectedVideo = toPlay
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
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
            Form {
                Section("Sort by") {
                    Picker("Sort", selection: $draft.sortOrder) {
                        ForEach(SearchFilter.SortOrder.allCases, id: \.self) { order in
                            Text(LocalizedStringKey(order.label)).tag(order)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }

                Section("Upload date") {
                    Picker("Upload date", selection: $draft.uploadDate) {
                        ForEach(SearchFilter.UploadDate.allCases, id: \.self) { date in
                            Text(LocalizedStringKey(date.label)).tag(date)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }

                Section(String(localized: "search.filter.type", bundle: .module)) {
                    Picker(String(localized: "search.filter.type", bundle: .module), selection: $draft.type) {
                        ForEach(SearchFilter.VideoType.allCases, id: \.self) { type in
                            Text(LocalizedStringKey(type.label)).tag(type)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }

                Section("Duration") {
                    Picker("Duration", selection: $draft.duration) {
                        ForEach(SearchFilter.Duration.allCases, id: \.self) { dur in
                            Text(LocalizedStringKey(dur.label)).tag(dur)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }
            }
            .navigationTitle("Search filters")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        onApply(draft)
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .accessibilityIdentifier("search.filterSheet")
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Idle") {
    NavigationStack { SearchView() }
        .previewEnvironment()
}

#Preview("Results") {
    NavigationStack { SearchView() }
        .environment(SearchViewModel.preview(query: "open movies"))
        .previewEnvironment()
}

#Preview("No results") {
    NavigationStack { SearchView() }
        .environment(SearchViewModel.preview(query: "zzzzzz", results: []))
        .previewEnvironment()
}
#endif

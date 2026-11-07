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
    #if !os(tvOS)
    @FocusState private var isSearchFocused: Bool
    #endif
    #if os(iOS)
    @Environment(PlayerRouter.self) private var playerRouter
    #endif

    public init() {}

    public var body: some View {
        #if os(tvOS)
        @Bindable var vm = vm
        #endif
        VStack(spacing: 0) {
            #if os(tvOS)
            if !vm.query.isEmpty {
                tvFilterRow
            }
            #else
            searchBar
            Divider()
            if !vm.query.isEmpty {
                filterChipsRow
            }
            #endif
            Group {
                #if os(tvOS)
                if vm.query.isEmpty {
                    tvIdleView
                } else if vm.isLoading || vm.isAwaitingSearch || !vm.results.isEmpty {
                    resultsView
                } else {
                    noResultsView
                }
                #else
                if isSearchFocused {
                    suggestionsListView
                } else if vm.isLoading || !vm.results.isEmpty {
                    resultsView
                } else if !vm.query.isEmpty {
                    noResultsView
                } else {
                    suggestionsListView
                }
                #endif
            }
        }
        #if os(tvOS)
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
        #elseif os(iOS)
        .toolbar(.hidden, for: .navigationBar)
        #endif
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
        #if !os(tvOS)
        .onChange(of: isSearchFocused) { _, focused in
            if focused { Task { await vm.updateSuggestions(for: vm.query) } }
        }
        #endif
    }

    #if !os(tvOS)
    // MARK: - Search bar

    private var searchBar: some View {
        @Bindable var vm = vm
        return HStack(spacing: 8) {
            Image(systemName: AppSymbol.search)
                .foregroundStyle(.secondary)
            TextField("Search YouTube", text: $vm.query)
                .focused($isSearchFocused)
                .submitLabel(.search)
                .autocorrectionDisabled()
                .accessibilityIdentifier("search.bar")
                #if os(iOS)
            .textInputAutocapitalization(.never)
                #endif
                .onSubmit {
                    vm.search()
                    isSearchFocused = false
                }
            if !vm.query.isEmpty {
                Button {
                    vm.query = ""
                } label: {
                    Image(systemName: AppSymbol.xmarkCircle)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("search.clearButton")
            }
            Button {
                showFilterSheet = true
            } label: {
                Image(systemName: filterSymbol)
                    .foregroundStyle(vm.filter.isDefault ? .secondary : Color.accentColor)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("search.filterButton")
        }
        .padding(10)
        .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    // MARK: - Active filter row

    @ViewBuilder
    private var filterChipsRow: some View {
        if !vm.filter.isDefault {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    activeFilterChips
                }
                .padding(.horizontal)
                .padding(.vertical, 6)
            }
            Divider()
        }
    }
    #endif

    #if os(tvOS)
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
    #endif

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
                        #if os(tvOS)
                        await vm.recordCurrentSearch()
                        #endif
                        await CurrentQueueStore.shared.replaceAll(with: captured)
                        let startIdx = captured.firstIndex(where: { $0.id == video.id }) ?? 0
                        let toPlay = await CurrentQueueStore.shared.videoAt(index: startIdx) ?? video
                        #if os(iOS)
                        playerRouter.open(video: toPlay, api: api)
                        #else
                        selectedVideo = toPlay
                        #endif
                    }
                },
                loadMore: vm.loadMore
            )
            if vm.isLoading && !vm.results.isEmpty {
                ProgressView().frame(maxWidth: .infinity).padding()
            }
        }
        .accessibilityIdentifier("search.results")
        #if os(iOS)
        .scrollDismissesKeyboard(.immediately)
        .contentShape(Rectangle())
        .onTapGesture { isSearchFocused = false }
        #endif
    }

    #if !os(tvOS)
    // MARK: - Suggestions list (history + recommended/live)

    private var suggestionsListView: some View {
        let suggestionsHeader = vm.query.isEmpty ? "Recommended" : "Suggestions"
        return List {
            // History section — only shown when there are matching entries
            if !vm.filteredHistory.isEmpty {
                Section(header: Text("Recent").font(.caption).foregroundStyle(.secondary)) {
                    ForEach(vm.filteredHistory) { entry in
                        Button {
                            vm.query = entry.query
                            vm.search()
                            isSearchFocused = false
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "clock")
                                    .foregroundStyle(.secondary)
                                    .frame(width: 20)
                                Text(entry.query)
                                    .foregroundStyle(.primary)
                                Spacer()
                                #if os(iOS)
                                Button {
                                    vm.removeHistoryEntry(entry.query)
                                } label: {
                                    Image(systemName: AppSymbol.xmark)
                                        .foregroundStyle(.secondary)
                                        .font(.caption)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Remove \(entry.query) from history")
                                #endif
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("search.history.\(entry.query)")
                    }
                    Button(role: .destructive) {
                        vm.clearHistory()
                    } label: {
                        Text("Clear History")
                            .font(.subheadline)
                            .frame(maxWidth: .infinity)
                    }
                    .accessibilityIdentifier("search.history.clearAll")
                }
            }

            // Suggestions / Recommended section (existing behaviour)
            Section(header: Text(suggestionsHeader).font(.caption).foregroundStyle(.secondary)) {
                ForEach(vm.suggestions, id: \.self) { suggestion in
                    Button {
                        vm.query = suggestion
                        vm.search()
                        isSearchFocused = false
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: AppSymbol.search)
                                .foregroundStyle(.secondary)
                                .frame(width: 20)
                            Text(suggestion)
                                .foregroundStyle(.primary)
                            Spacer()
                            Button {
                                vm.query = suggestion
                            } label: {
                                Image(systemName: "arrow.up.left")
                                    .foregroundStyle(.secondary)
                                    .font(.caption)
                            }
                            .buttonStyle(.plain)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .listStyle(.plain)
        .accessibilityIdentifier("search.suggestionsContainer")
        // Tapping empty list space (outside a row) must dismiss the keyboard.
        // Task #202: the resultsView and noResultsView already had this gesture
        // but suggestionsListView (shown while keyboard is open) was missing it.
        // .contentShape(Rectangle()) makes the transparent empty space tappable.
        .contentShape(Rectangle())
        .onTapGesture { isSearchFocused = false }
    }
    #endif

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
        #if os(iOS)
        .contentShape(Rectangle())
        .onTapGesture { isSearchFocused = false }
        #endif
    }
}

// MARK: - FilterChip

private struct FilterChip: View {
    let label: LocalizedStringKey
    let onRemove: () -> Void

    var body: some View {
        #if os(tvOS)
        // A single focusable button: the Siri Remote can't reach a tiny inner target.
        Button(action: onRemove) {
            Label {
                Text(label)
            } icon: {
                Image(systemName: AppSymbol.xmark)
            }
        }
        #else
        HStack(spacing: 4) {
            Text(label)
                .font(.caption)
            Button(action: onRemove) {
                Image(systemName: AppSymbol.xmark)
                    .font(.caption2)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(.tint.opacity(0.15), in: Capsule())
        .foregroundStyle(.tint)
        #endif
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
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
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
                #if os(iOS)
                ToolbarItem(placement: .bottomBar) {
                    Button("Reset") { draft = .default }
                        .disabled(draft.isDefault)
                }
                #endif
            }
        }
        .presentationDetents([.medium, .large])
        .accessibilityIdentifier("search.filterSheet")
    }
}

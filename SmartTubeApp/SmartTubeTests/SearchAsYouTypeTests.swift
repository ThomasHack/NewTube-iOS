import Foundation
import Testing

@testable import SmartTube
@testable import SmartTubeCore

// MARK: - SearchAsYouTypeTests

@Suite("SearchViewModel search-as-you-type")
@MainActor
struct SearchAsYouTypeTests {

    private func makeVM(api: MockInnerTubeAPI) -> SearchViewModel {
        SearchViewModel(api: api, historyStore: SearchHistoryStore(suiteName: "test-\(UUID().uuidString)"))
    }

    private func makeAPI() -> MockInnerTubeAPI {
        let api = MockInnerTubeAPI()
        api.searchResult = VideoGroup(
            title: "Results",
            videos: [Video(id: "result_AAAAA", title: "Result", channelTitle: "Channel")]
        )
        return api
    }

    private func searchCount(_ api: MockInnerTubeAPI) -> Int {
        api.calls.filter { $0.method == "search" }.count
    }

    @Test("Typed text produces results without adding the partial query to history")
    func typingDoesNotRecordHistory() async {
        let api = makeAPI()
        let vm = makeVM(api: api)
        vm.query = "swi"

        await vm.searchAsYouType(debounce: .zero)
        await vm.loadHistory()

        #expect(vm.results.map(\.id) == ["result_AAAAA"])
        #expect(vm.history.isEmpty)
    }

    @Test("recordCurrentSearch adds the query to history once the user acts on it")
    func recordCurrentSearchAddsHistory() async {
        let vm = makeVM(api: makeAPI())
        vm.query = "  swift  "

        await vm.recordCurrentSearch()

        #expect(vm.history.map(\.query) == ["swift"])
    }

    @Test("The same query isn't searched twice")
    func sameQueryIsNotRepeated() async {
        let api = makeAPI()
        let vm = makeVM(api: api)
        vm.query = "swift"

        await vm.searchAsYouType(debounce: .zero)
        vm.query = "swift "
        await vm.searchAsYouType(debounce: .zero)

        #expect(searchCount(api) == 1)
    }

    @Test("A query already run by search() isn't searched again")
    func explicitSearchIsNotRepeated() async {
        let api = makeAPI()
        let vm = makeVM(api: api)
        vm.query = "swift"
        vm.search()

        await vm.searchAsYouType(debounce: .zero)

        #expect(!vm.isAwaitingSearch)
    }

    @Test("Clearing the text clears results")
    func emptyQueryClearsResults() async {
        let vm = makeVM(api: makeAPI())
        vm.query = "swift"
        await vm.searchAsYouType(debounce: .zero)

        vm.query = ""
        await vm.searchAsYouType(debounce: .zero)

        #expect(vm.results.isEmpty)
        #expect(!vm.isLoading)
        #expect(!vm.isAwaitingSearch)
    }

    @Test("isAwaitingSearch covers the gap between typing and the search starting")
    func awaitingSearchUntilStarted() async {
        let vm = makeVM(api: makeAPI())
        #expect(!vm.isAwaitingSearch)

        vm.query = "swift"
        #expect(vm.isAwaitingSearch)

        await vm.searchAsYouType(debounce: .zero)
        #expect(!vm.isAwaitingSearch)
    }
}

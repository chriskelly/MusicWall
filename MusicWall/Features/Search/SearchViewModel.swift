import Foundation
import Observation

@MainActor
@Observable
final class SearchViewModel {
    var query = ""
    private(set) var catalogResults: [AlbumRecord] = []
    private(set) var libraryResults: [AlbumRecord] = []
    private(set) var isSearching = false
    var errorMessage: String?

    private let repository: any AlbumRepository
    private let debounce: Duration
    private let minimumQueryLength: Int

    /// Bumped by every new query (typed or submitted). A search may only publish results
    /// while its generation is still the latest, so a slow response to an older query cannot
    /// overwrite the results of a newer one.
    private var generation = 0

    /// The last request pair that started, used to ignore a submit for the text that is
    /// already being searched. It may refer to a superseded generation; the generation check
    /// keeps a stale pair from suppressing a new search.
    private var inFlight: (query: String, generation: Int)?

    init(
        repository: any AlbumRepository,
        debounce: Duration = .milliseconds(300),
        minimumQueryLength: Int = 2
    ) {
        self.repository = repository
        self.debounce = debounce
        self.minimumQueryLength = minimumQueryLength
    }

    /// Typed-input entry point: waits out the debounce, then searches the settled query.
    /// The view drives this from `.task(id:)` keyed on the trimmed query, so a keystroke
    /// cancels the previous invocation; the generation guard covers a repository call that
    /// ignores cancellation.
    func queryDidChange() async {
        generation &+= 1
        let searchGeneration = generation

        let query = trimmedQuery
        guard query.count >= minimumQueryLength else {
            resetSearchState()
            return
        }

        // This query owns the search state now. A response for an earlier query is discarded
        // below, so it must not leave the spinner on while this query waits out its debounce.
        isSearching = false
        errorMessage = nil

        do {
            try await Task.sleep(for: debounce)
        } catch {
            return
        }

        guard searchGeneration == generation else { return }
        await performSearch(query, generation: searchGeneration)
    }

    /// Immediate entry point for the Search button and the keyboard submit key.
    func search() async {
        let query = trimmedQuery
        guard !query.isEmpty else {
            generation &+= 1
            resetSearchState()
            return
        }
        // The button is disabled while a search runs, but the submit key is not, so ignore a
        // submit for the text that is already being searched.
        if let inFlight, inFlight.generation == generation, inFlight.query == query {
            return
        }

        generation &+= 1
        errorMessage = nil

        await performSearch(query, generation: generation)
    }

    /// The query with leading and trailing whitespace removed. The minimum-length check, the
    /// search itself, and the view's `.task(id:)` all key off this form.
    var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func resetSearchState() {
        catalogResults = []
        libraryResults = []
        isSearching = false
        inFlight = nil
        errorMessage = nil
    }

    private func performSearch(_ query: String, generation searchGeneration: Int) async {
        isSearching = true
        inFlight = (query, searchGeneration)
        errorMessage = nil

        async let catalogTask = repository.search(query: query, source: .catalog)
        async let libraryTask = repository.search(query: query, source: .library)

        var catalog: [AlbumRecord] = []
        var library: [AlbumRecord] = []
        var errorParts: [String] = []

        do {
            catalog = try await catalogTask
        } catch {
            errorParts.append("Apple Music: \(error.localizedDescription)")
        }

        do {
            library = try await libraryTask
        } catch {
            errorParts.append("Library: \(error.localizedDescription)")
        }

        guard searchGeneration == generation else { return }
        guard !Task.isCancelled else {
            isSearching = false
            inFlight = nil
            return
        }

        catalogResults = catalog
        libraryResults = library
        isSearching = false
        inFlight = nil
        errorMessage = errorParts.isEmpty ? nil : errorParts.joined(separator: "\n")
    }
}

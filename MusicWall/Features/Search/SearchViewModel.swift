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

    init(repository: any AlbumRepository) {
        self.repository = repository
    }

    func search() async {
        guard !query.isEmpty else { return }

        isSearching = true
        errorMessage = nil

        async let catalogTask = repository.search(query: query, source: .catalog)
        async let libraryTask = repository.search(query: query, source: .library)

        var errorParts: [String] = []

        do {
            catalogResults = try await catalogTask
        } catch {
            catalogResults = []
            errorParts.append("Apple Music: \(error.localizedDescription)")
        }

        do {
            libraryResults = try await libraryTask
        } catch {
            libraryResults = []
            errorParts.append("Library: \(error.localizedDescription)")
        }

        isSearching = false
        errorMessage = errorParts.isEmpty ? nil : errorParts.joined(separator: "\n")
    }
}

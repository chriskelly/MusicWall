import Foundation
@testable import MusicWall

final class MockURLSession: URLSessionDataProviding, @unchecked Sendable {
    var dataHandler: ((URL) async throws -> (Data, URLResponse))?
    private(set) var dataCalls: [URL] = []

    func data(from url: URL) async throws -> (Data, URLResponse) {
        dataCalls.append(url)
        if let dataHandler { return try await dataHandler(url) }
        return (Data(), URLResponse())
    }
}

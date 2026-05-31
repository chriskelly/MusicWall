import Foundation

protocol URLSessionDataProviding: Sendable {
    func data(from url: URL) async throws -> (Data, URLResponse)
}

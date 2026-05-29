import Foundation

protocol SecurityScopedReader: Sendable {
    func readData(from url: URL) throws -> Data
}

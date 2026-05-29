import Foundation

protocol MusicAuthorizationProviding: Sendable {
    var authorizationStatus: MusicAuthorizationStatus { get }
    func requestAuthorization() async -> MusicAuthorizationStatus
}

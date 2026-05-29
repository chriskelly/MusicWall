import Foundation

enum MusicAuthorizationStatus: Sendable, Equatable {
    case notDetermined
    case authorized
    case denied
    case restricted
    case unknown
}

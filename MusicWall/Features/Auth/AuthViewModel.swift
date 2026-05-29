import Foundation
import Observation

enum AuthState: Equatable {
    case loading
    case authorized
    case denied
}

@MainActor
@Observable
final class AuthViewModel {
    private(set) var state: AuthState = .loading
    private let authorization: any MusicAuthorizationProviding

    init(authorization: any MusicAuthorizationProviding) {
        self.authorization = authorization
    }

    func checkAuthorization() async {
        switch authorization.authorizationStatus {
        case .authorized:
            state = .authorized
        case .notDetermined:
            state = .loading
            let status = await authorization.requestAuthorization()
            applyAfterRequest(status)
        case .denied, .restricted, .unknown:
            state = .denied
        }
    }

    func retry() async {
        state = .loading
        let status = await authorization.requestAuthorization()
        applyAfterRequest(status)
    }

    private func applyAfterRequest(_ status: MusicAuthorizationStatus) {
        switch status {
        case .authorized:
            state = .authorized
        case .notDetermined, .denied, .restricted, .unknown:
            state = .denied
        }
    }
}

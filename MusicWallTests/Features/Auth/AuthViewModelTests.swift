import Testing
@testable import MusicWall

struct AuthViewModelTests {
    @Test @MainActor
    func initialAuthorized_skipsRequest() async {
        let provider = MockMusicAuthorizationProvider(authorizationStatus: .authorized)
        let viewModel = AuthViewModel(authorization: provider)

        await viewModel.checkAuthorization()

        #expect(viewModel.state == .authorized)
        #expect(provider.requestCallCount == 0)
    }

    @Test @MainActor
    func initialNotDetermined_requestAuthorized() async {
        let provider = MockMusicAuthorizationProvider(authorizationStatus: .notDetermined)
        provider.requestHandler = { .authorized }
        let viewModel = AuthViewModel(authorization: provider)

        await viewModel.checkAuthorization()

        #expect(viewModel.state == .authorized)
        #expect(provider.requestCallCount == 1)
    }

    @Test @MainActor
    func initialNotDetermined_requestDenied() async {
        let provider = MockMusicAuthorizationProvider(authorizationStatus: .notDetermined)
        provider.requestHandler = { .denied }
        let viewModel = AuthViewModel(authorization: provider)

        await viewModel.checkAuthorization()

        #expect(viewModel.state == .denied)
        #expect(provider.requestCallCount == 1)
    }

    @Test @MainActor
    func initialNotDetermined_requestNotDetermined() async {
        let provider = MockMusicAuthorizationProvider(authorizationStatus: .notDetermined)
        provider.requestHandler = { .notDetermined }
        let viewModel = AuthViewModel(authorization: provider)

        await viewModel.checkAuthorization()

        #expect(viewModel.state == .denied)
    }

    @Test @MainActor
    func initialNotDetermined_requestRestricted() async {
        let provider = MockMusicAuthorizationProvider(authorizationStatus: .notDetermined)
        provider.requestHandler = { .restricted }
        let viewModel = AuthViewModel(authorization: provider)

        await viewModel.checkAuthorization()

        #expect(viewModel.state == .denied)
    }

    @Test @MainActor
    func initialNotDetermined_requestUnknown() async {
        let provider = MockMusicAuthorizationProvider(authorizationStatus: .notDetermined)
        provider.requestHandler = { .unknown }
        let viewModel = AuthViewModel(authorization: provider)

        await viewModel.checkAuthorization()

        #expect(viewModel.state == .denied)
    }

    @Test @MainActor
    func initialDenied_skipsRequest() async {
        let provider = MockMusicAuthorizationProvider(authorizationStatus: .denied)
        let viewModel = AuthViewModel(authorization: provider)

        await viewModel.checkAuthorization()

        #expect(viewModel.state == .denied)
        #expect(provider.requestCallCount == 0)
    }

    @Test @MainActor
    func initialRestricted_skipsRequest() async {
        let provider = MockMusicAuthorizationProvider(authorizationStatus: .restricted)
        let viewModel = AuthViewModel(authorization: provider)

        await viewModel.checkAuthorization()

        #expect(viewModel.state == .denied)
        #expect(provider.requestCallCount == 0)
    }

    @Test @MainActor
    func initialUnknown_skipsRequest() async {
        let provider = MockMusicAuthorizationProvider(authorizationStatus: .unknown)
        let viewModel = AuthViewModel(authorization: provider)

        await viewModel.checkAuthorization()

        #expect(viewModel.state == .denied)
        #expect(provider.requestCallCount == 0)
    }

    @Test @MainActor
    func retry_fromDenied_toAuthorized() async {
        let provider = MockMusicAuthorizationProvider(authorizationStatus: .denied)
        provider.requestHandler = { .authorized }
        let viewModel = AuthViewModel(authorization: provider)
        await viewModel.checkAuthorization()
        #expect(viewModel.state == .denied)

        await viewModel.retry()

        #expect(viewModel.state == .authorized)
        #expect(provider.requestCallCount == 1)
    }

    @Test @MainActor
    func retry_fromDenied_staysDenied() async {
        for status in [MusicAuthorizationStatus.notDetermined, .denied, .restricted, .unknown] {
            let provider = MockMusicAuthorizationProvider(authorizationStatus: .denied)
            provider.requestHandler = { status }
            let viewModel = AuthViewModel(authorization: provider)
            await viewModel.checkAuthorization()

            await viewModel.retry()

            #expect(viewModel.state == .denied)
        }
    }
}

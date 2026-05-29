//
//  ContentView.swift
//  MusicWall
//
//  Created by Chris Kelly on 8/27/25.
//

import SwiftUI

struct ContentView: View {
    let dependencies: AppDependencies
    @State private var viewModel: AuthViewModel

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
        _viewModel = State(
            initialValue: AuthViewModel(authorization: dependencies.musicAuthorization)
        )
    }

    var body: some View {
        Group {
            switch viewModel.state {
            case .authorized:
                let store = dependencies.preferencesStore
                HomePageView(
                    store: AlbumStore(
                        preferences: store,
                        repository: dependencies.albumRepository
                    ),
                    preferences: store,
                    dependencies: dependencies
                )
            case .denied:
                authorizationDeniedView()
            case .loading:
                ProgressView("Requesting Music Access…")
            }
        }
        .task {
            await viewModel.checkAuthorization()
        }
    }

    private func authorizationDeniedView() -> some View {
        VStack {
            Text("Apple Music access is required to use this app.")
                .multilineTextAlignment(.center)
                .padding()
            Button("Try Again") {
                Task {
                    await viewModel.retry()
                }
            }
        }
    }
}

#Preview {
    ContentView(dependencies: .preview())
}

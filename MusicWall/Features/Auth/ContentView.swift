//
//  ContentView.swift
//  MusicWall
//
//  Created by Chris Kelly on 8/27/25.
//

import SwiftUI
import UIKit

struct ContentView: View {
    let dependencies: AppDependencies
    @State private var viewModel: AuthViewModel
    @State private var homeViewModel: HomeViewModel
    @Environment(\.openURL) private var openURL

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
        _viewModel = State(
            initialValue: AuthViewModel(authorization: dependencies.musicAuthorization)
        )
        _homeViewModel = State(
            initialValue: HomeViewModel(
                preferences: dependencies.preferencesStore,
                repository: dependencies.albumRepository,
                backup: dependencies.albumBackupService
            )
        )
    }

    var body: some View {
        Group {
            switch viewModel.state {
            case .authorized:
                HomePageView(viewModel: homeViewModel, dependencies: dependencies)
            case .denied:
                authorizationDeniedView()
            case .loading:
                ProgressView("Requesting Music Access…")
            }
        }
        .task {
            await viewModel.checkAuthorization()
        }
        .overlay {
            if UITestConfiguration.isEnabled,
               let playback = dependencies.playbackController as? UITestPlaybackController {
                UITestStateReader(playback: playback)
            }
        }
    }

    private func authorizationDeniedView() -> some View {
        VStack(spacing: 16) {
            Text("Apple Music access is required to use this app.")
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Text("If you previously denied access, enable Apple Music in Settings, then tap Try Again.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    openURL(url)
                }
            }
            Button("Try Again") {
                Task {
                    await viewModel.retry()
                }
            }
        }
        .padding()
    }
}

#Preview {
    ContentView(dependencies: .preview())
}

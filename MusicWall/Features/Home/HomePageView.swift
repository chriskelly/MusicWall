//
//  HomePageView.swift
//  MusicWall
//
//  Created by Chris Kelly on 8/29/25.
//

import SwiftUI
import UIKit

struct HomePageView: View {
    @Bindable var viewModel: HomeViewModel
    let dependencies: AppDependencies
    @State private var showingAddView = false
    @State private var showingFileImporter = false
    @State private var exportedFileURL: URL?
    @State private var showingExportShareSheet = false

    var body: some View {
        NavigationStack {
            layoutView()
                .navigationTitle("My Albums")
                .toolbar { toolbarView() }
                .background(Color(.systemGray6))
        }
        .environment(viewModel.store)
        .environment(\.albumRepository, dependencies.albumRepository)
        .environment(\.playback, dependencies.playbackController)
        .environment(\.artworkProvider, dependencies.artworkProvider)
        .sheet(isPresented: $showingAddView) {
            AlbumSearchView(
                repository: dependencies.albumRepository,
                onSelect: onSearchSelect
            )
        }
        .snackbar(
            isPresented: Binding(
                get: { viewModel.snackbar != nil },
                set: { if !$0 { viewModel.snackbar = nil } }
            ),
            message: viewModel.snackbar?.message ?? ""
        )
        .fileImporter(
            isPresented: $showingFileImporter,
            allowedContentTypes: [.json, .text],
            allowsMultipleSelection: false
        ) { result in
            handleFileImport(result: result)
        }
        .sheet(isPresented: $showingExportShareSheet) {
            if let url = exportedFileURL {
                ShareSheet(activityItems: [url])
            }
        }
        .task { await viewModel.load() }
    }

    private func layoutView() -> some View {
        Group {
            switch viewModel.currentLayout {
            case .grid:
                GridLayout()
            case .list:
                ListLayout()
            }
        }
    }

    private func toolbarView() -> some View {
        Group {
            HomePageMenu(
                viewModel: viewModel,
                showingFileImporter: $showingFileImporter,
                onExport: handleExport
            )
            Button("Shuffle albums temporarily", systemImage: "shuffle.circle") {
                withAnimation {
                    viewModel.shuffleAlbums()
                }
            }
            Button("Add album", systemImage: "plus") {
                showingAddView = true
            }
            .accessibilityIdentifier("home.addAlbum")
        }
    }

    private func onSearchSelect(_ record: AlbumRecord) {
        viewModel.store.addAlbum(record)
        viewModel.albumAdded()
    }

    private func handleFileImport(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            Task {
                await viewModel.importAlbums(from: url)
            }
        case .failure(let error):
            viewModel.importFailed(error)
        }
    }

    private func handleExport() {
        switch viewModel.exportAlbums() {
        case .success(let url):
            exportedFileURL = url
            showingExportShareSheet = true
        case .snackbar(let state):
            viewModel.snackbar = state
        }
    }
}

struct HomePageMenu: View {
    @Bindable var viewModel: HomeViewModel
    @Binding var showingFileImporter: Bool
    let onExport: () -> Void

    var body: some View {
        Menu {
            LayoutMenu(viewModel: viewModel)
            SortMenu(viewModel: viewModel)
            BackupMenu(showingFileImporter: $showingFileImporter, onExport: onExport)
        } label: {
            Label("Options", systemImage: "line.3.horizontal.decrease.circle")
        }
    }
}

struct SortMenu: View {
    @Bindable var viewModel: HomeViewModel

    var body: some View {
        Section {
            ForEach(AlbumStore.SortOption.allCases) { option in
                Button {
                    withAnimation {
                        viewModel.selectSort(option)
                    }
                } label: {
                    HStack {
                        if viewModel.currentSort == option {
                            Image(systemName: viewModel.isAscending(for: option) ? "arrow.down" : "arrow.up")
                                .foregroundColor(.accentColor)
                        }
                        Text(option.rawValue)
                    }
                }
            }
        }
    }
}

struct BackupMenu: View {
    @Binding var showingFileImporter: Bool
    let onExport: () -> Void

    var body: some View {
        Section("Backup") {
            Button("Export Album IDs", systemImage: "square.and.arrow.up") {
                onExport()
            }
            Button("Import Album IDs", systemImage: "square.and.arrow.down") {
                showingFileImporter = true
            }
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    let deps = AppDependencies.preview()
    HomePageView(viewModel: .preview(dependencies: deps), dependencies: deps)
}

#Preview {
    let deps = AppDependencies.preview()
    NavigationStack {
        HomePageView(viewModel: .preview(dependencies: deps), dependencies: deps)
    }
}

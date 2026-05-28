//
//  HomePageView.swift
//  MusicWall
//
//  Created by Chris Kelly on 8/29/25.
//

import SwiftUI
import UIKit

struct HomePageView: View {
    @State var albums: StoredAlbums
    let preferences: PreferencesStore
    let dependencies: AppDependencies
    @State private var showingAddView = false
    @State private var currentLayout: LayoutMenu.Option
    @State private var showingAlbumAddSnackbar = false
    @State private var showingFileImporter = false
    @State private var exportedFileURL: URL?
    @State private var showingExportShareSheet = false
    @State private var showingImportSnackbar = false
    @State private var importSnackbarMessage = ""

    init(albums: StoredAlbums, preferences: PreferencesStore, dependencies: AppDependencies) {
        self._albums = State(initialValue: albums)
        self.preferences = preferences
        self.dependencies = dependencies
        self._currentLayout = State(
            initialValue: LayoutMenu.loadLayout(using: preferences) ?? .grid
        )
    }
    
    var body: some View {
        NavigationStack {
            layoutView()
            .navigationTitle("My Albums")
            .toolbar {toolbarView()}
            .background(Color(.systemGray6))
        }
        .environment(albums)
        .environment(\.albumRepository, dependencies.albumRepository)
        .environment(\.playback, dependencies.playbackController)
        .sheet(isPresented: $showingAddView) {
            AlbumSearchView(
                repository: dependencies.albumRepository,
                onSelect: onSearchSelect
            )
        }
        .snackbar(isPresented: $showingAlbumAddSnackbar, message: "Album successfully added!")
        .snackbar(isPresented: $showingImportSnackbar, message: importSnackbarMessage)
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
        .task {await albums.load()}
    }
    
    private func layoutView() -> some View {
        return Group {
            switch currentLayout {
            case .grid:
                GridLayout()
            case .list:
                ListLayout()
            }
        }
    }
    
    private func toolbarView() -> some View {
        return Group {
            HomePageMenu(
                currentLayout: $currentLayout,
                showingFileImporter: $showingFileImporter,
                preferences: preferences,
                onExport: exportAlbums
            )
            Button("Shuffle albums temporarily", systemImage: "shuffle.circle") {
                withAnimation {
                    albums.temporarilyShuffle()
                }
            }
            Button("Add album", systemImage: "plus") {
                showingAddView = true
            }
        }
    }
    
    private func onSearchSelect(_ record: AlbumRecord) {
        albums.addAlbum(StoredAlbum(from: record))
        showingAlbumAddSnackbar = true
    }
    
    private func handleFileImport(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            Task {
                await importAlbums(from: url)
            }
        case .failure(let error):
            importSnackbarMessage = "Import failed: \(error.localizedDescription)"
            showingImportSnackbar = true
        }
    }
    
    @MainActor
    private func importAlbums(from url: URL) async {
        do {
            let ids = try BackupService.importAlbumIDs(from: url)
            try await albums.importAlbums(from: ids)
            importSnackbarMessage = "Successfully imported \(ids.count) album(s)!"
            showingImportSnackbar = true
        } catch {
            importSnackbarMessage = "Import failed: \(error.localizedDescription)"
            showingImportSnackbar = true
        }
    }
    
    private func exportAlbums() {
        let ids = albums.exportAlbumIDs()
        
        do {
            let url = try BackupService.exportAlbumIDs(ids)
            exportedFileURL = url
            showingExportShareSheet = true
        } catch {
            importSnackbarMessage = "Export failed: \(error.localizedDescription)"
            showingImportSnackbar = true
        }
    }
}

struct HomePageMenu: View {
    @Binding var currentLayout: LayoutMenu.Option
    @Binding var showingFileImporter: Bool
    let preferences: PreferencesStore
    let onExport: () -> Void
    
    var body: some View {
        Menu {
            LayoutMenu(currentLayout: $currentLayout, preferences: preferences)
            SortMenu()
            BackupMenu(showingFileImporter: $showingFileImporter, onExport: onExport)
        } label: {
            Label("Options", systemImage: "line.3.horizontal.decrease.circle")
        }
    }
}

struct SortMenu: View {
    @Environment(StoredAlbums.self) private var albums
    
    var body: some View {
        Section {
            ForEach(StoredAlbums.SortOptions.allCases) {option in
                Button {
                    if albums.currentSort == option {
                        albums.toggleSortDirection(for: option)
                    } else {
                        albums.currentSort = option
                    }
                    withAnimation {
                        albums.applySort()
                    }
                } label: {
                    HStack {
                        if albums.currentSort == option {
                            Image(systemName: albums.isAscending(for: option) ? "arrow.down" : "arrow.up")
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
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    let deps = AppDependencies.preview()
    HomePageView(
        albums: StoredAlbums.dummyData(preferences: deps.preferencesStore, repository: deps.albumRepository),
        preferences: deps.preferencesStore,
        dependencies: deps
    )
}


#Preview {
    let deps = AppDependencies.preview()
    NavigationStack {
        HomePageView(
            albums: StoredAlbums.dummyData(preferences: deps.preferencesStore, repository: deps.albumRepository),
            preferences: deps.preferencesStore,
            dependencies: deps
        )
    }
}

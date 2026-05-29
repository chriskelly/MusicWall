//
//  LayoutView.swift
//  MusicWall
//
//  Created by Chris Kelly on 10/1/25.
//

import SwiftUI

struct LayoutContainer<Content: View>: View {
    @Environment(AlbumStore.self) private var store
    @State private var deletedAlbum: AlbumRecord?
    @State private var showAlbumDeleteSnackbar = false
    @State private var editingAlbum: AlbumRecord?
    
    private let content: (
        _ onDeleteSnackbar: @escaping (AlbumRecord) -> Void,
        _ onEdit: @escaping (AlbumRecord) -> Void
    ) -> Content
    
    init(@ViewBuilder content: @escaping (
        _ onDeleteSnackbar: @escaping (AlbumRecord) -> Void, 
        _ onEdit: @escaping (AlbumRecord) -> Void
    ) -> Content) {
        self.content = content
    }
    
    private func handleDeleteSnackbar(album: AlbumRecord) {
        deletedAlbum = album
        showAlbumDeleteSnackbar = true
    }
    
    private func handleEdit(album: AlbumRecord) {
        editingAlbum = album
    }
    
    var body: some View {
        content(
            handleDeleteSnackbar,
            handleEdit
        )
        .snackbar(
            isPresented: $showAlbumDeleteSnackbar,
            message: "Removed \(deletedAlbum?.title ?? "album")",
            actionLabel: "Undo",
            action: {
                if let album = deletedAlbum {
                    store.addAlbum(album)
                }
            }
        )
        .sheet(item: $editingAlbum) { album in
            AlbumEditView(album: album) { updatedAlbum in
                store.updateAlbum(updatedAlbum)
            }
        }
    }
}

struct GridLayout: View {
    @Environment(AlbumStore.self) private var store
    @Environment(\.playback) private var playback
    @State private var selectedAlbumID: String?
    
    private static let size = CGFloat(150)
    
    var body: some View {
        LayoutContainer { onDeleteSnackbar, onEdit in
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: GridLayout.size))]) {
                    ForEach(store.items) { album in
                        AlbumTile(
                            album: album,
                            isSelected: selectedAlbumID == album.id.rawValue,
                            onDeleteSnackbar: onDeleteSnackbar,
                            onEdit: onEdit
                        )
                        .onTapGesture {
                            Task {
                                await AlbumTapPlayback.handleTap(
                                    albumID: AlbumID(rawValue: album.id.rawValue),
                                    rawSelectedID: selectedAlbumID,
                                    setSelected: { selectedAlbumID = $0 },
                                    playback: playback
                                )
                            }
                        }
                    }
                }
                .padding(20)
            }
        }
    }
    
    struct AlbumTile: View {
        let album: AlbumRecord
        let isSelected: Bool
        let onDeleteSnackbar: (AlbumRecord) -> Void
        let onEdit: (AlbumRecord) -> Void
        
        @State private var animationID = UUID()
        @Environment(AlbumStore.self) private var store
        
        var body: some View {
            VStack {
                vinylAnimation(AlbumArtwork(album: album, viewSize: GridLayout.size))
                Text(album.title)
                    .lineLimit(1)
                    .allowsTightening(true)
                    .font(.headline)
                Text(album.artistName)
                    .lineLimit(1)
                    .allowsTightening(true)
                    .font(.footnote)
            }
            .contextMenu {tileContextMenu()}
            .padding(.bottom, 25)
        }
        
        private func vinylAnimation(_ content: some View) -> some View {
            content
                .frame(width: isSelected ? 50 : GridLayout.size,
                       height: isSelected ? 50 : GridLayout.size)
                .clipShape(
                    isSelected
                    ? AnyShape(Circle())
                    : AnyShape(RoundedRectangle(cornerRadius: 20))
                )
                .overlay(
                    Circle().inset(by: -25).stroke(Color.black.opacity(0.95), lineWidth: isSelected ? 50 : 0)
                )
                .overlay(Circle().inset(by: -5).stroke(Color.black, lineWidth: isSelected ? 5 : 0))
                .overlay(Circle().inset(by: -20).stroke(Color.black, lineWidth: isSelected ? 2 : 0))
                .overlay(Circle().inset(by: -35).stroke(Color.black, lineWidth: isSelected ? 2 : 0))
                .frame(width: GridLayout.size, height: GridLayout.size)
                .animation(.default, value: isSelected)
                .rotationEffect(.degrees(isSelected ? 360 : 0))
                .animation(
                    isSelected
                    ? .linear(duration: 1.5).repeatForever(autoreverses: false)
                    : .default,
                    value: isSelected
                )
                .id(animationID)
                .onChange(of: isSelected, { wasSelected, isNowSelected in
                    if wasSelected && !isNowSelected {
                        animationID = UUID() // forces the View to rebuild, which is necessary to force all animations to stop even when out of view
                    }
                })
        }
        
        private func tileContextMenu() -> some View {
            Group {
                Button {
                    onEdit(album)
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
                
                Button(role: .destructive) {
                    store.remove(album: album)
                    onDeleteSnackbar(album)
                } label: {
                    Label("Remove Album", systemImage: "trash")
                }
            }
        }
    }
}

struct ListLayout: View {
    @Environment(AlbumStore.self) private var store
    @Environment(\.playback) private var playback
    @State private var selectedAlbumID: String?
    
    var body: some View {
        LayoutContainer { onDeleteSnackbar, onEdit in
            List {
                ForEach(store.items) { album in
                    listItem(album)
                        .onTapGesture {
                            Task {
                                await AlbumTapPlayback.handleTap(
                                    albumID: AlbumID(rawValue: album.id.rawValue),
                                    rawSelectedID: selectedAlbumID,
                                    setSelected: { selectedAlbumID = $0 },
                                    playback: playback
                                )
                            }
                        }
                        .swipeActions(edge: .leading) {
                            Button {
                                onEdit(album)
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            .tint(.blue)
                        }
                }
                .onDelete { indexSet in
                    let deletedAlbum = indexSet.first.map { store.items[$0] }
                    store.remove(atOffsets: indexSet)
                    if let deletedAlbum {
                        onDeleteSnackbar(deletedAlbum)
                    }
                }
            }
        }
    }
    
    private func listItem(_ album: AlbumRecord) -> some View {
        return HStack {
            VStack(alignment: .leading) {
                Text(album.title)
                    .font(.headline)
                Text(album.artistName)
                    .font(.footnote)
            }
            Spacer()
            AlbumArtwork(album: album, viewSize: CGFloat(60))
        }
    }
}

struct AlbumArtwork: View {
    let album: AlbumRecord
    let viewSize: CGFloat

    @Environment(\.albumRepository) private var albumRepository
    @State private var imageURL: URL?
    
    var body: some View {
        AsyncImage(url: imageURL) { image in
            image
                .resizable()
                .scaledToFit()
                .frame(width: viewSize, height: viewSize)
        } placeholder: {
            ProgressView()
        }
        .task {
            let scale = UIScreen.main.scale   // @2x for most iPhones, @3x on latest pro/max models
            let pixelSize = Int((viewSize * scale).rounded())
            imageURL = await ImageCache(repository: albumRepository).getArtwork(
                albumID: album.id.rawValue,
                size: pixelSize
            )
        }
    }
}

struct LayoutMenu: View {
    @Binding var currentLayout: Option
    let preferences: PreferencesStore
    
    enum Option: String, CaseIterable, Identifiable, Codable {
        var id: String { rawValue }
        
        case grid = "Grid"
        case list = "List"
    }
    
    var body: some View {
        Section {
            ForEach(LayoutMenu.Option.allCases) { option in
                Button {
                    currentLayout = option
                    preferences.save(currentLayout, for: .homePageLayout)
                } label: {
                    HStack {
                        if currentLayout == option {
                            Image(systemName: "checkmark")
                        }
                        Text(option.rawValue)
                    }
                }
                
            }
        }
    }
    
    static func loadLayout(using preferences: PreferencesStore) -> Option? {
        preferences.load(Option.self, for: .homePageLayout)
    }
}

#Preview {
    @Previewable @State var layout: LayoutMenu.Option = .grid
    let deps = AppDependencies.preview()
    let store = AlbumStore.dummyData(
        preferences: deps.preferencesStore,
        repository: deps.albumRepository
    )
    LayoutMenu(currentLayout: $layout, preferences: deps.preferencesStore)
    ListLayout()
        .environment(store)
        .environment(\.albumRepository, deps.albumRepository)
        .environment(\.playback, deps.playbackController)
    GridLayout()
        .environment(store)
        .environment(\.albumRepository, deps.albumRepository)
        .environment(\.playback, deps.playbackController)
}


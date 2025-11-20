//
//  LayoutView.swift
//  MusicWall
//
//  Created by Chris Kelly on 10/1/25.
//

import SwiftUI

struct LayoutContainer<Content: View>: View {
    @Environment(StoredAlbums.self) private var albums
    @State private var deletedAlbum: StoredAlbum?
    @State private var showAlbumDeleteSnackbar = false
    @State private var editingAlbum: StoredAlbum?
    
    private let content: (
        _ onDeleteSnackbar: @escaping (StoredAlbum) -> Void,
        _ onEdit: @escaping (StoredAlbum) -> Void
    ) -> Content
    
    init(@ViewBuilder content: @escaping (
        _ onDeleteSnackbar: @escaping (StoredAlbum) -> Void, 
        _ onEdit: @escaping (StoredAlbum) -> Void
    ) -> Content) {
        self.content = content
    }
    
    private func handleDeleteSnackbar(album: StoredAlbum) {
        deletedAlbum = album
        showAlbumDeleteSnackbar = true
    }
    
    private func handleEdit(album: StoredAlbum) {
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
                    albums.addAlbum(album)
                }
            }
        )
        .sheet(item: $editingAlbum) { album in
            AlbumEditView(album: album) { updatedAlbum in
                albums.updateAlbum(updatedAlbum)
            }
        }
    }
}

struct GridLayout: View {
    @Environment(StoredAlbums.self) private var albums
    @State private var selectedAlbumID: String?
    
    private static let size = CGFloat(150)
    
    var body: some View {
        LayoutContainer { onDeleteSnackbar, onEdit in
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: GridLayout.size))]) {
                    ForEach(albums.items) { album in
                        AlbumTile(
                            album: album,
                            isSelected: selectedAlbumID == album.id.rawValue,
                            onDeleteSnackbar: onDeleteSnackbar,
                            onEdit: onEdit
                        )
                        .onTapGesture {onAlbumTapped(
                            album: album,
                            selectedAlbumIdBinding: $selectedAlbumID
                        )}
                    }
                }
                .padding(20)
            }
        }
    }
    
    struct AlbumTile: View {
        let album: StoredAlbum
        let isSelected: Bool
        let onDeleteSnackbar: (StoredAlbum) -> Void
        let onEdit: (StoredAlbum) -> Void
        
        @State private var animationID = UUID()
        @Environment(StoredAlbums.self) private var albums
        
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
                    if let index = albums.items.firstIndex(where: { $0.id == album.id }) {
                        albums.items.remove(at: index)
                        onDeleteSnackbar(album)
                    }
                } label: {
                    Label("Remove Album", systemImage: "trash")
                }
            }
        }
    }
}

struct ListLayout: View {
    @Environment(StoredAlbums.self) private var albums
    @State private var selectedAlbumID: String?
    
    var body: some View {
        LayoutContainer { onDeleteSnackbar, onEdit in
            List {
                ForEach(albums.items) { album in
                    listItem(album)
                        .onTapGesture {onAlbumTapped(
                            album: album, 
                            selectedAlbumIdBinding: $selectedAlbumID
                        )}
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
                    let deletedAlbums = indexSet.map { albums.items[$0] }
                    albums.items.remove(atOffsets: indexSet)
                    if !deletedAlbums.isEmpty {
                        onDeleteSnackbar(deletedAlbums.first!)
                    }
                }
            }
        }
    }
    
    private func listItem(_ album: StoredAlbum) -> some View {
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

private func onAlbumTapped(album: StoredAlbum, selectedAlbumIdBinding: Binding<String?>) {
    if selectedAlbumIdBinding.wrappedValue == album.id.rawValue {
        album.pause()
        selectedAlbumIdBinding.wrappedValue = nil
    } else {
        selectedAlbumIdBinding.wrappedValue = album.id.rawValue
        Task {
            do {
                try await album.play()
            } catch {
                print(error.localizedDescription)
            }
        }
    }
}

struct AlbumArtwork: View {
    let album: StoredAlbum
    let viewSize: CGFloat
    
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
            imageURL = await ImageCache().getArtwork(
                albumID: album.id.rawValue,
                size: pixelSize
            )
        }
    }
}

struct LayoutMenu: View {
    @Binding var currentLayout: Option
    
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
                    UserDefaultsManager.setData(key: .homePageLayoutKey, data: currentLayout)
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
    
    static func loadLayout() -> Option? {
        return UserDefaultsManager.loadData(
            key: .homePageLayoutKey,
            type: Option.self
        )
    }
}

#Preview {
    @Previewable @State var layout: LayoutMenu.Option = .grid
    LayoutMenu(currentLayout: $layout)
    ListLayout()
        .environment(StoredAlbums.dummyData())
    GridLayout()
        .environment(StoredAlbums.dummyData())
    
}


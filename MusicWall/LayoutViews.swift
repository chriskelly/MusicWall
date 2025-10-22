//
//  LayoutView.swift
//  MusicWall
//
//  Created by Chris Kelly on 10/1/25.
//

import SwiftUI

struct GridLayout: View {
    @Environment(SavedAlbums.self) private var albums
    @State private var selectedAlbumID: String?
    
    private static let size = CGFloat(150)
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: GridLayout.size))]) {
                ForEach(albums.items) { album in
                    AlbumTile(album: album, isSelected: selectedAlbumID == album.id.rawValue)
                        .onTapGesture {
                            selectedAlbumID = album.id.rawValue
                            Task {await album.play()}
                        }
                }
            }
            .padding(20)
        }
    }
    
    struct AlbumTile: View {
        let album: SavedAlbum
        let isSelected: Bool
        
        @State private var animationID = UUID()
        @Environment(SavedAlbums.self) private var albums
        
        var body: some View {
            VStack {
                AlbumArtwork(album: album, viewSize: GridLayout.size)
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
                Text(album.title)
                    .lineLimit(1)
                    .allowsTightening(true)
                    .font(.headline)
                Text(album.artistName)
                    .lineLimit(1)
                    .allowsTightening(true)
                    .font(.footnote)
            }
            .contextMenu {
                Button(role: .destructive) {
                    if let index = albums.items.firstIndex(where: { $0.id == album.id }) {
                        albums.items.remove(at: index)
                    }
                } label: {
                    Label("Remove Album", systemImage: "trash")
                }
            }
            .padding(.bottom, 25)
        }
    }
}

struct ListLayout: View {
    @Environment(SavedAlbums.self) private var albums
    
    var body: some View {
        List {
            ForEach(albums.items) { album in
                HStack {
                    VStack(alignment: .leading) {
                        Text(album.title)
                            .font(.headline)
                        Text(album.artistName)
                            .font(.footnote)
                    }
                    Spacer()
                    AlbumArtwork(album: album, viewSize: CGFloat(60))
                }
                .onTapGesture {
                    Task {await album.play()}
                }
            }
            .onDelete { indexSet in
                albums.items.remove(atOffsets: indexSet)
            }
        }
    }
}

struct AlbumArtwork: View {
    let album: SavedAlbum
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
        .environment(SavedAlbums.dummyData())
    GridLayout()
        .environment(SavedAlbums.dummyData())
    
}


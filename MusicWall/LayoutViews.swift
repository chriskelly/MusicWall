//
//  LayoutView.swift
//  MusicWall
//
//  Created by Chris Kelly on 10/1/25.
//

import SwiftUI

struct GridLayout: View {
    @Environment(SavedAlbums.self) private var albums
    
    private let size = CGFloat(150)
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: size))]) {
                ForEach(albums.items) { album in
                    VStack{
                        VStack {
                            AlbumArtwork(album: album, viewSize: size)
                                .frame(width: size, height: size)
                                .clipShape(RoundedRectangle(cornerRadius: 20))
                            Text(album.title)
                                .lineLimit(1)
                                .allowsTightening(true)
                                .font(.headline)
                            Text(album.artistName)
                                .lineLimit(1)
                                .allowsTightening(true)
                                .font(.footnote)
                        }
                        .onTapGesture {
                            Task {await album.play()}
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
                        Spacer(minLength: 50)
                    }
                }
            }
            .padding(20)
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

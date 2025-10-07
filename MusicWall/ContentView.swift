//
//  ContentView.swift
//  MusicWall
//
//  Created by Chris Kelly on 8/27/25.
//

import SwiftUI
import MusicKit

struct ContentView: View {
    @State private var isAuthorized = false
    @State private var authorizationDenied = false
    
    var body: some View {
        Group {
            if isAuthorized {
                HomePageView(albums: SavedAlbums())
            } else if authorizationDenied {
                VStack {
                    Text("Apple Music access is required to use this app.")
                        .multilineTextAlignment(.center)
                        .padding()
                    Button("Try Again") {
                        Task {
                            await requestAuthorization()
                        }
                    }
                }
            } else {
                ProgressView("Requesting Music Access…")
            }
        }
        .task {
            await requestAuthorization()
        }
    }
    
    func requestAuthorization() async {
        let status = await MusicAuthorization.request()
        switch status {
        case .authorized:
            isAuthorized = true
        case .denied, .restricted, .notDetermined:
            isAuthorized = false
            authorizationDenied = true
        @unknown default:
            isAuthorized = false
            authorizationDenied = true
        }
    }
}

class UserDefaultsManager {
    enum Key: String {
        case savedAlbumsItemsKey = "savedAlbumsItemsKey"
        case backupAlbumIDsKey = "backupIDsKey"
        case sortDirectionKey = "sortDirectionKey"
        case currentSortKey = "currentSortKey"
        case homePageLayoutKey = "homePageLayoutKey"
    }
    
    static func setData<T:Encodable>(key:Key, data: T) {
        if let encoded = try? JSONEncoder().encode(data) {
            UserDefaults.standard.set(encoded, forKey: key.rawValue)
        }
    }
    
    static func loadData<T:Decodable>(key: Key, type: T.Type) -> T? {
        if let data = UserDefaults.standard.data(forKey: key.rawValue) {
            if let decoded = try? JSONDecoder().decode(type, from: data) {
                return decoded
            }
        }
        return nil
    }
}


#Preview {
    ContentView()
}

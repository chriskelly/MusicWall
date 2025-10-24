//
//  UserDefaultsManager.swift
//  MusicWall
//
//  Created by Chris Kelly on 10/22/25.
//


import SwiftUI
import MusicKit

class UserDefaultsManager {
    enum Key: String {
        case storedAlbumsItemsKey = "savedAlbumsItemsKey"
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

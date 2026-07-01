import Foundation

enum MusicWallDeepLink {
    static let scheme = "musicwall"
    static let addAlbumHost = "add-album"
    private static let albumIDQueryName = "id"

    static func addAlbumURL(albumID: String) -> URL? {
        var components = URLComponents()
        components.scheme = scheme
        components.host = addAlbumHost
        components.queryItems = [URLQueryItem(name: albumIDQueryName, value: albumID)]
        return components.url
    }

    static func albumID(from url: URL) -> String? {
        guard url.scheme?.lowercased() == scheme,
              url.host?.lowercased() == addAlbumHost
        else { return nil }

        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        guard let id = components?.queryItems?
            .first(where: { $0.name == albumIDQueryName })?
            .value,
            !id.isEmpty
        else { return nil }
        return id
    }
}

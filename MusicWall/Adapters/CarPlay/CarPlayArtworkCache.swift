import UIKit

struct CarPlayArtworkCache {
    struct Key: Hashable {
        let albumID: AlbumID
        let pixelSize: Int
    }

    private(set) var images: [Key: UIImage] = [:]
    private var loadedPixelSize: Int?

    mutating func resetIfNeeded(pixelSize: Int) {
        guard loadedPixelSize != pixelSize else { return }
        images.removeAll()
        loadedPixelSize = pixelSize
    }

    func image(for albumID: AlbumID, pixelSize: Int) -> UIImage? {
        images[Key(albumID: albumID, pixelSize: pixelSize)]
    }

    mutating func store(_ image: UIImage, albumID: AlbumID, pixelSize: Int) {
        images[Key(albumID: albumID, pixelSize: pixelSize)] = image
    }

    func isFullyCached(albums: [AlbumRecord], pixelSize: Int) -> Bool {
        albums.allSatisfy { image(for: $0.id, pixelSize: pixelSize) != nil }
    }

    func missingAlbums(from albums: [AlbumRecord], pixelSize: Int) -> [AlbumRecord] {
        albums.filter { image(for: $0.id, pixelSize: pixelSize) == nil }
    }
}

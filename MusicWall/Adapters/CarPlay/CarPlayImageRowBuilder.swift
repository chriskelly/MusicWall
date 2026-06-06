import CarPlay
import UIKit

@MainActor
enum CarPlayImageRowBuilder {
    static let albumsPerRow = 8

    static func makeAlbumLibraryTemplate(
        albums: [AlbumRecord],
        imageForAlbum: (AlbumID) -> UIImage,
        onSelectAlbum: @escaping @MainActor (AlbumID) -> Void
    ) -> CPListTemplate? {
        guard #available(iOS 26.0, *) else { return nil }
        let rowChunks = chunk(albums, size: albumsPerRow)
        let maxRows = Int(CPListTemplate.maximumItemCount)
        let cappedChunks = Array(rowChunks.prefix(maxRows))

        let items: [CPListImageRowItem] = cappedChunks.map { chunk in
            makeCardImageRowItem(
                albums: chunk,
                imageForAlbum: imageForAlbum,
                onSelectAlbum: onSelectAlbum
            )
        }
        guard !items.isEmpty else { return nil }
        let section = CPListSection(items: items)
        return CPListTemplate(title: nil, sections: [section])
    }

    static func placeholderImage() -> UIImage {
        UIImage(systemName: "music.note") ?? UIImage()
    }

    @available(iOS 26.0, *)
    private static func makeCardImageRowItem(
        albums: [AlbumRecord],
        imageForAlbum: (AlbumID) -> UIImage,
        onSelectAlbum: @escaping @MainActor (AlbumID) -> Void
    ) -> CPListImageRowItem {
        let albumIDs = albums.map(\.id)
        let elements = albums.map {
            CPListImageRowItemCardElement(
                image: imageForAlbum($0.id),
                showsImageFullHeight: false,
                title: $0.title,
                subtitle: $0.artistName,
                tintColor: nil
            )
        }
        let rowItem = CPListImageRowItem(
            text: nil,
            cardElements: elements,
            allowsMultipleLines: true
        )
        rowItem.userInfo = albumIDs
        rowItem.listImageRowHandler = { item, index, completion in
            guard
                let ids = item.userInfo as? [AlbumID],
                index >= 0,
                index < ids.count
            else {
                completion()
                return
            }
            Task { @MainActor in
                onSelectAlbum(ids[index])
                completion()
            }
        }
        return rowItem
    }

    private static func chunk<T>(_ values: [T], size: Int) -> [[T]] {
        guard size > 0, !values.isEmpty else { return [] }
        return stride(from: 0, to: values.count, by: size).map { start in
            Array(values[start..<min(start + size, values.count)])
        }
    }
}

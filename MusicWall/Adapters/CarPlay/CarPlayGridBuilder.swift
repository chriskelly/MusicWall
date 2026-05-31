import CarPlay
import UIKit

@MainActor
enum CarPlayGridBuilder {
    static func makeTemplates(
        pages: [[AlbumRecord]],
        imageForAlbum: (AlbumID) -> UIImage,
        onSelectAlbum: @escaping @MainActor (AlbumID) -> Void
    ) -> [CPGridTemplate] {
        pages.enumerated().map { pageIndex, pageAlbums in
            let buttons = pageAlbums.map { album in
                CPGridButton(
                    titleVariants: [album.title],
                    image: imageForAlbum(album.id)
                ) { _ in
                    onSelectAlbum(album.id)
                }
            }
            let title = pages.count > 1 ? "Albums \(pageIndex + 1)/\(pages.count)" : "Albums"
            return CPGridTemplate(title: title, gridButtons: buttons)
        }
    }

    static func placeholderImage() -> UIImage {
        UIImage(systemName: "music.note") ?? UIImage()
    }
}

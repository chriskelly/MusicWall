import CarPlay
import UIKit

@MainActor
enum CarPlayGridBuilder {
    static func makeTemplates(
        pages: [[AlbumRecord]],
        imageForAlbum: (AlbumID) -> UIImage,
        onSelectAlbum: @escaping @MainActor (AlbumID) -> Void
    ) -> [CPGridTemplate] {
        pages.map { pageAlbums in
            let buttons = pageAlbums.map { album in
                CPGridButton(
                    titleVariants: [album.title],
                    image: imageForAlbum(album.id)
                ) { _ in
                    onSelectAlbum(album.id)
                }
            }
            return CPGridTemplate(
                title: CarPlayCopy.appName,
                gridButtons: buttons
            )
        }
    }

    static func placeholderImage() -> UIImage {
        UIImage(systemName: "music.note") ?? UIImage()
    }
}

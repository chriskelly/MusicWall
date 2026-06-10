import CarPlay
import UIKit

@MainActor
final class CarPlayCoordinator {
    private struct AlbumLibraryPresentation: Equatable {
        let animated: Bool
        let skipArtworkLoadWhenCached: Bool

        static let connect = AlbumLibraryPresentation(
            animated: true,
            skipArtworkLoadWhenCached: false
        )
        static let shuffle = AlbumLibraryPresentation(
            animated: false,
            skipArtworkLoadWhenCached: true
        )
    }

    private struct ArtworkCacheKey: Hashable {
        let albumID: AlbumID
        let pixelSize: Int
    }

    private let interfaceController: CPInterfaceController
    private let dependencies: AppDependencies
    private let store: AlbumStore
    private let imageCache: ImageCache
    private var artworkByKey: [ArtworkCacheKey: UIImage] = [:]
    private var loadedArtworkPixelSize: Int?
    private var albumLibraryTemplate: CPListTemplate?

    init(
        interfaceController: CPInterfaceController,
        dependencies: AppDependencies
    ) {
        self.interfaceController = interfaceController
        self.dependencies = dependencies
        self.store = AlbumStore(
            preferences: dependencies.preferencesStore,
            repository: dependencies.albumRepository
        )
        self.imageCache = ImageCache(artworkProvider: dependencies.artworkProvider)
    }

    func connect() async {
        let authorizationStatus = dependencies.musicAuthorization
            .authorizationStatus

        let albums: [AlbumRecord]
        if authorizationStatus == .authorized {
            await store.load()
            albums = store.items
        } else {
            albums = []
        }

        let screen = CarPlayConnectPlanner.rootScreen(
            authorizationStatus: authorizationStatus,
            albums: albums
        )
        switch screen {
        case .setupRequired:
            albumLibraryTemplate = nil
            await setRootTemplate(CarPlaySetupTemplate.make(), animated: true)
        case .albumLibrary(let albums):
            await presentAlbumLibrary(albums, presentation: .connect)
        }
    }

    private func presentAlbumLibrary(
        _ albums: [AlbumRecord],
        presentation: AlbumLibraryPresentation
    ) async {
        guard #available(iOS 26.0, *) else {
            albumLibraryTemplate = nil
            await setRootTemplate(CarPlaySetupTemplate.make(), animated: true)
            return
        }

        let placeholder = CarPlayImageRowBuilder.placeholderImage()
        let pixelSize = artworkPixelSize()
        let shouldLoadArtwork = !presentation.skipArtworkLoadWhenCached
            || !isArtworkCached(for: albums, pixelSize: pixelSize)
        if shouldLoadArtwork {
            await ensureArtworkLoaded(for: albums, pixelSize: pixelSize)
        }

        let imageForAlbum: (AlbumID) -> UIImage = { [artworkByKey] albumID in
            let key = ArtworkCacheKey(albumID: albumID, pixelSize: pixelSize)
            return artworkByKey[key] ?? placeholder
        }
        let onSelectAlbum: @MainActor (AlbumID) -> Void = { [weak self] albumID in
            guard let self else { return }
            Task { await self.play(albumID: albumID) }
        }

        guard
            let template = CarPlayImageRowBuilder.makeAlbumLibraryTemplate(
                albums: albums,
                imageForAlbum: imageForAlbum,
                onSelectAlbum: onSelectAlbum
            )
        else {
            albumLibraryTemplate = nil
            await setRootTemplate(CarPlaySetupTemplate.make(), animated: true)
            return
        }

        await applyAlbumLibraryTemplate(template, presentation: presentation)
    }

    private func applyAlbumLibraryTemplate(
        _ template: CPListTemplate,
        presentation: AlbumLibraryPresentation
    ) async {
        if presentation == .shuffle, let existing = albumLibraryTemplate {
            existing.updateSections(template.sections)
            configureBarButtons(for: existing)
            return
        }

        albumLibraryTemplate = template
        configureBarButtons(for: template)
        await setRootTemplate(template, animated: presentation.animated)
    }

    @available(iOS 26.0, *)
    private func artworkPixelSize() -> Int {
        let traits = interfaceController.carTraitCollection
        let scale = traits.displayScale
        let pt = CPListImageRowItemCardElement.maximumImageSize
        return max(1, Int(max(pt.width, pt.height) * scale))
    }

    private func configureBarButtons(for template: CPListTemplate) {
        template.backButton = nil
        template.leadingNavigationBarButtons = []
        template.trailingNavigationBarButtons = [
            CarPlayBarButtons.shuffle { [weak self] _ in
                guard let self else { return }
                Task { await self.shuffleAndRefresh() }
            },
        ]
    }

    private func setRootTemplate(_ template: CPTemplate, animated: Bool) async {
        _ = try? await interfaceController.setRootTemplate(template, animated: animated)
    }

    private func shuffleAndRefresh() async {
        store.temporarilyShuffle()
        await presentAlbumLibrary(store.items, presentation: .shuffle)
    }

    private func isArtworkCached(
        for albums: [AlbumRecord],
        pixelSize: Int
    ) -> Bool {
        albums.allSatisfy { album in
            artworkByKey[ArtworkCacheKey(albumID: album.id, pixelSize: pixelSize)] != nil
        }
    }

    private func play(albumID: AlbumID) async {
        try? await dependencies.playbackController.play(albumId: albumID)
    }

    private func ensureArtworkLoaded(
        for albums: [AlbumRecord],
        pixelSize: Int
    ) async {
        if loadedArtworkPixelSize != pixelSize {
            artworkByKey.removeAll()
            loadedArtworkPixelSize = pixelSize
        }

        for album in albums {
            let key = ArtworkCacheKey(
                albumID: album.id,
                pixelSize: pixelSize
            )
            if artworkByKey[key] != nil {
                continue
            }

            guard
                let url = await imageCache.getArtwork(
                    albumID: album.id.rawValue,
                    size: pixelSize
                )
            else { continue }

            guard
                let data = try? Data(contentsOf: url),
                let image = UIImage(data: data)
            else { continue }
            artworkByKey[key] = image
        }
    }
}

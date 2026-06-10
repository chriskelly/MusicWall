import CarPlay
import UIKit

@MainActor
final class CarPlayCoordinator {
    private struct AlbumLibraryPresentation: Equatable {
        let animated: Bool
        let loadsArtworkInBackground: Bool

        static let connect = AlbumLibraryPresentation(
            animated: true,
            loadsArtworkInBackground: true
        )
        static let shuffle = AlbumLibraryPresentation(
            animated: false,
            loadsArtworkInBackground: false
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
    private var artworkLoadGeneration = 0
    private var shuffleBarButton: CPBarButton?
    private var isShuffling = false

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
        resetArtworkCacheIfNeeded(pixelSize: pixelSize)

        guard
            let template = buildAlbumLibraryTemplate(
                albums: albums,
                pixelSize: pixelSize,
                placeholder: placeholder
            )
        else {
            albumLibraryTemplate = nil
            await setRootTemplate(CarPlaySetupTemplate.make(), animated: true)
            return
        }

        await applyAlbumLibraryTemplate(template, presentation: presentation)

        guard !isArtworkCached(for: albums, pixelSize: pixelSize) else { return }

        let generation = artworkLoadGeneration
        if presentation.loadsArtworkInBackground {
            Task {
                await loadMissingArtworkAndRefresh(
                    albums: albums,
                    pixelSize: pixelSize,
                    generation: generation
                )
            }
        } else {
            await loadMissingArtworkAndRefresh(
                albums: albums,
                pixelSize: pixelSize,
                generation: generation
            )
        }
    }

    private func buildAlbumLibraryTemplate(
        albums: [AlbumRecord],
        pixelSize: Int,
        placeholder: UIImage
    ) -> CPListTemplate? {
        let imageForAlbum: (AlbumID) -> UIImage = { [artworkByKey] albumID in
            let key = ArtworkCacheKey(albumID: albumID, pixelSize: pixelSize)
            return artworkByKey[key] ?? placeholder
        }
        let onSelectAlbum: @MainActor (AlbumID) -> Void = { [weak self] albumID in
            guard let self else { return }
            Task { await self.play(albumID: albumID) }
        }

        return CarPlayImageRowBuilder.makeAlbumLibraryTemplate(
            albums: albums,
            imageForAlbum: imageForAlbum,
            onSelectAlbum: onSelectAlbum
        )
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
        let shuffle = CarPlayBarButtons.shuffle { [weak self] _ in
            guard let self else { return }
            Task { await self.shuffleAndRefresh() }
        }
        shuffleBarButton = shuffle
        template.trailingNavigationBarButtons = [shuffle]
    }

    private func setShuffleBarButtonLoading(_ isLoading: Bool) {
        shuffleBarButton?.isEnabled = !isLoading
        shuffleBarButton?.image = isLoading
            ? CarPlayBarButtons.shuffleBusyImage()
            : CarPlayBarButtons.shuffleImage()
    }

    private func setRootTemplate(_ template: CPTemplate, animated: Bool) async {
        _ = try? await interfaceController.setRootTemplate(template, animated: animated)
    }

    private func shuffleAndRefresh() async {
        guard !isShuffling else { return }
        isShuffling = true
        setShuffleBarButtonLoading(true)
        defer {
            isShuffling = false
            setShuffleBarButtonLoading(false)
        }

        artworkLoadGeneration += 1
        store.temporarilyShuffle()
        await presentAlbumLibrary(store.items, presentation: .shuffle)
    }

    private func resetArtworkCacheIfNeeded(pixelSize: Int) {
        guard loadedArtworkPixelSize != pixelSize else { return }
        artworkByKey.removeAll()
        loadedArtworkPixelSize = pixelSize
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

    private func loadMissingArtworkAndRefresh(
        albums: [AlbumRecord],
        pixelSize: Int,
        generation: Int
    ) async {
        await ensureArtworkLoaded(for: albums, pixelSize: pixelSize)
        guard generation == artworkLoadGeneration else { return }
        guard let existing = albumLibraryTemplate else { return }

        let placeholder = CarPlayImageRowBuilder.placeholderImage()
        guard
            let template = buildAlbumLibraryTemplate(
                albums: albums,
                pixelSize: pixelSize,
                placeholder: placeholder
            )
        else { return }

        existing.updateSections(template.sections)
        configureBarButtons(for: existing)
    }

    private func ensureArtworkLoaded(
        for albums: [AlbumRecord],
        pixelSize: Int
    ) async {
        let missing = albums.filter { album in
            artworkByKey[ArtworkCacheKey(albumID: album.id, pixelSize: pixelSize)] == nil
        }
        guard !missing.isEmpty else { return }

        await withTaskGroup(of: (ArtworkCacheKey, UIImage)?.self) { group in
            for album in missing {
                let albumID = album.id
                let key = ArtworkCacheKey(albumID: albumID, pixelSize: pixelSize)
                group.addTask { [imageCache] in
                    guard
                        let url = await imageCache.getArtwork(
                            albumID: albumID.rawValue,
                            size: pixelSize
                        )
                    else { return nil }

                    guard
                        let data = try? Data(contentsOf: url),
                        let image = UIImage(data: data)
                    else { return nil }

                    return (key, image)
                }
            }

            for await result in group {
                guard let (key, image) = result else { continue }
                artworkByKey[key] = image
            }
        }
    }
}

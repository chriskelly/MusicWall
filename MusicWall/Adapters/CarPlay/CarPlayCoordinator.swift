import CarPlay
import UIKit

@MainActor
final class CarPlayCoordinator {
    private let interfaceController: CPInterfaceController
    private let dependencies: AppDependencies
    private let store: AlbumStore
    private let imageCache: ImageCache
    private var artworkCache = CarPlayArtworkCache()
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
        presentation: CarPlayAlbumLibraryPresentation
    ) async {
        guard #available(iOS 26.0, *) else {
            albumLibraryTemplate = nil
            await setRootTemplate(CarPlaySetupTemplate.make(), animated: true)
            return
        }

        let placeholder = CarPlayImageRowBuilder.placeholderImage()
        let pixelSize = artworkPixelSize()
        artworkCache.resetIfNeeded(pixelSize: pixelSize)

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

        guard !artworkCache.isFullyCached(albums: albums, pixelSize: pixelSize) else { return }

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
        let imageForAlbum: (AlbumID) -> UIImage = { [artworkCache] albumID in
            artworkCache.image(for: albumID, pixelSize: pixelSize) ?? placeholder
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
        presentation: CarPlayAlbumLibraryPresentation
    ) async {
        if presentation.updatesSectionsInPlace, let existing = albumLibraryTemplate {
            existing.updateSections(template.sections)
            configureBarButtons(for: existing)
            return
        }

        albumLibraryTemplate = template
        configureBarButtons(for: template)
        await setRootTemplate(template, animated: presentation.setsRootAnimated)
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
        if isShuffling {
            setShuffleBarButtonLoading(true)
        }
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

        rebuildAndUpdateSections(on: existing, albums: albums, pixelSize: pixelSize)
    }

    private func rebuildAndUpdateSections(
        on template: CPListTemplate,
        albums: [AlbumRecord],
        pixelSize: Int
    ) {
        let placeholder = CarPlayImageRowBuilder.placeholderImage()
        guard
            let rebuilt = buildAlbumLibraryTemplate(
                albums: albums,
                pixelSize: pixelSize,
                placeholder: placeholder
            )
        else { return }

        template.updateSections(rebuilt.sections)
        configureBarButtons(for: template)
    }

    private func ensureArtworkLoaded(
        for albums: [AlbumRecord],
        pixelSize: Int
    ) async {
        let missing = artworkCache.missingAlbums(from: albums, pixelSize: pixelSize)
        guard !missing.isEmpty else { return }

        await withTaskGroup(of: (CarPlayArtworkCache.Key, UIImage)?.self) { group in
            for album in missing {
                let albumID = album.id
                let key = CarPlayArtworkCache.Key(albumID: albumID, pixelSize: pixelSize)
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
                artworkCache.store(image, albumID: key.albumID, pixelSize: key.pixelSize)
            }
        }
    }
}

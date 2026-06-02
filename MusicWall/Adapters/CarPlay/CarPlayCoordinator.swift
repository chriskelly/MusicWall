import CarPlay
import UIKit

@MainActor
final class CarPlayCoordinator {
    private static let artworkPixelSize = 200

    private let interfaceController: CPInterfaceController
    private let dependencies: AppDependencies
    private let store: AlbumStore
    private let imageCache: ImageCache
    private var gridTemplates: [CPGridTemplate] = []
    private var artworkByAlbumID: [AlbumID: UIImage] = [:]

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
            await setRootTemplate(CarPlaySetupTemplate.make())
        case .albumGrid(let pages):
            await presentGrid(pages: pages)
        }
    }

    private func presentGrid(pages: [[AlbumRecord]]) async {
        let placeholder = CarPlayGridBuilder.placeholderImage()
        let flatAlbums = pages.flatMap(\.self)
        await ensureArtworkLoaded(for: flatAlbums)

        gridTemplates = CarPlayGridBuilder.makeTemplates(
            pages: pages,
            imageForAlbum: { [artworkByAlbumID] albumID in
                artworkByAlbumID[albumID] ?? placeholder
            },
            onSelectAlbum: { [weak self] albumID in
                guard let self else { return }
                Task { await self.play(albumID: albumID) }
            }
        )
        guard let first = gridTemplates.first else {
            await setRootTemplate(CarPlaySetupTemplate.make())
            return
        }
        configureBarButtons(for: first, pageIndex: 0)
        await setRootTemplate(first)
    }

    private func configureBarButtons(
        for template: CPGridTemplate,
        pageIndex: Int
    ) {
        template.backButton = nil

        let isSinglePageGrid = gridTemplates.count == 1
        template.leadingNavigationBarButtons =
            pageIndex == 0 && isSinglePageGrid
            ? [CarPlayBarButtons.layoutSpacer()]
            : []

        // trailingNavigationBarButtons are outermost-first: forward (next page) is
        // rightmost; shuffle sits to its left (toward the title).
        var trailing: [CPBarButton] = []
        if pageIndex < gridTemplates.count - 1 {
            trailing.append(
                CarPlayBarButtons.forward { [weak self] _ in
                    guard let self else { return }
                    let nextIndex = pageIndex + 1
                    let nextTemplate = self.gridTemplates[nextIndex]
                    self.configureBarButtons(
                        for: nextTemplate,
                        pageIndex: nextIndex
                    )
                    Task {
                        try? await self.interfaceController.pushTemplate(
                            nextTemplate,
                            animated: true
                        )
                    }
                }
            )
        }

        trailing.append(
            CarPlayBarButtons.shuffle { [weak self] _ in
                guard let self else { return }
                Task { await self.shuffleAndRefresh() }
            },
        )
        template.trailingNavigationBarButtons = trailing
    }

    private func setRootTemplate(_ template: CPTemplate) async {
        try? await interfaceController.setRootTemplate(template, animated: true)
    }

    private func shuffleAndRefresh() async {
        store.temporarilyShuffle()
        let pages = CarPlayAlbumPaginator.pages(from: store.items)
        await presentGrid(pages: pages)
    }

    private func play(albumID: AlbumID) async {
        try? await dependencies.playbackController.play(albumId: albumID)
    }

    private func ensureArtworkLoaded(for albums: [AlbumRecord]) async {
        for album in albums {
            guard artworkByAlbumID[album.id] == nil else { continue }
            guard
                let url = await imageCache.getArtwork(
                    albumID: album.id.rawValue,
                    size: Self.artworkPixelSize
                ),
                let data = try? Data(contentsOf: url),
                let image = UIImage(data: data)
            else { continue }
            artworkByAlbumID[album.id] = image
        }
    }
}

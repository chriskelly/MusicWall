import CarPlay
import UIKit

@MainActor
final class CarPlayCoordinator {
    private let interfaceController: CPInterfaceController
    private let dependencies: AppDependencies
    private let store: AlbumStore
    private var gridTemplates: [CPGridTemplate] = []

    init(interfaceController: CPInterfaceController, dependencies: AppDependencies) {
        self.interfaceController = interfaceController
        self.dependencies = dependencies
        self.store = AlbumStore(
            preferences: dependencies.preferencesStore,
            repository: dependencies.albumRepository
        )
    }

    func connect() async {
        let screen = CarPlayConnectPlanner.rootScreen(
            authorizationStatus: dependencies.musicAuthorization.authorizationStatus,
            albums: await loadedAlbums()
        )
        switch screen {
        case .setupRequired:
            try? await interfaceController.setRootTemplate(CarPlaySetupTemplate.make(), animated: true)
        case .albumGrid(let pages):
            await presentGrid(pages: pages)
        }
    }

    private func loadedAlbums() async -> [AlbumRecord] {
        guard dependencies.musicAuthorization.authorizationStatus == .authorized else {
            return []
        }
        await store.load()
        return store.items
    }

    private func presentGrid(pages: [[AlbumRecord]]) async {
        let placeholder = CarPlayGridBuilder.placeholderImage()
        let artwork = await loadArtwork(for: pages.flatMap(\.self))
        gridTemplates = CarPlayGridBuilder.makeTemplates(
            pages: pages,
            imageForAlbum: { artwork[$0] ?? placeholder },
            onSelectAlbum: { [weak self] albumID in
                Task { await self?.play(albumID: albumID) }
            }
        )
        guard let first = gridTemplates.first else {
            try? await interfaceController.setRootTemplate(CarPlaySetupTemplate.make(), animated: true)
            return
        }
        attachNavigation(to: first, pageIndex: 0)
        attachShuffleBarButton(to: first)
        try? await interfaceController.setRootTemplate(first, animated: true)
    }

    private func attachShuffleBarButton(to template: CPGridTemplate) {
        let shuffle = CPBarButton(type: .text) { [weak self] _ in
            Task { await self?.shuffleAndRefresh() }
        }
        shuffle.title = "Shuffle"
        template.trailingNavigationBarButtons = [shuffle]
    }

    private func attachNavigation(to template: CPGridTemplate, pageIndex: Int) {
        guard gridTemplates.count > 1 else { return }
        var leadingButtons: [CPBarButton] = template.leadingNavigationBarButtons ?? []
        if pageIndex > 0 {
            let previous = CPBarButton(type: .text) { [weak self] _ in
                self?.interfaceController.popTemplate(animated: true)
            }
            previous.title = "Back"
            leadingButtons.append(previous)
        }
        template.leadingNavigationBarButtons = leadingButtons

        if pageIndex < gridTemplates.count - 1 {
            let next = CPBarButton(type: .text) { [weak self] _ in
                guard let self else { return }
                let nextIndex = pageIndex + 1
                let nextTemplate = self.gridTemplates[nextIndex]
                self.attachNavigation(to: nextTemplate, pageIndex: nextIndex)
                self.attachShuffleBarButton(to: nextTemplate)
                Task {
                    try? await self.interfaceController.pushTemplate(nextTemplate, animated: true)
                }
            }
            next.title = "Next"
            template.trailingNavigationBarButtons = (template.trailingNavigationBarButtons ?? []) + [next]
        }
    }

    private func shuffleAndRefresh() async {
        store.temporarilyShuffle()
        let pages = CarPlayAlbumPaginator.pages(from: store.items)
        await presentGrid(pages: pages)
    }

    private func play(albumID: AlbumID) async {
        _ = try? await dependencies.playbackController.play(albumId: albumID)
    }

    private func loadArtwork(for albums: [AlbumRecord]) async -> [AlbumID: UIImage] {
        let cache = ImageCache(artworkProvider: dependencies.artworkProvider)
        let pixelSize = 200
        var images: [AlbumID: UIImage] = [:]
        for album in albums {
            guard let url = await cache.getArtwork(albumID: album.id.rawValue, size: pixelSize),
                  let data = try? Data(contentsOf: url),
                  let image = UIImage(data: data) else { continue }
            images[album.id] = image
        }
        return images
    }
}

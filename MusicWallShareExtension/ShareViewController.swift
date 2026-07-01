import UIKit
import UniformTypeIdentifiers

final class ShareViewController: UIViewController {
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        processSharedContent()
    }

    private func processSharedContent() {
        guard let extensionItems = extensionContext?.inputItems as? [NSExtensionItem] else {
            finish()
            return
        }

        let providers = extensionItems
            .flatMap { $0.attachments ?? [] }
            .filter { provider in
                provider.hasItemConformingToTypeIdentifier(UTType.url.identifier)
                    || provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier)
            }

        guard let provider = providers.first else {
            finish()
            return
        }

        let typeIdentifier = provider.hasItemConformingToTypeIdentifier(UTType.url.identifier)
            ? UTType.url.identifier
            : UTType.plainText.identifier

        provider.loadItem(forTypeIdentifier: typeIdentifier) { [weak self] (item: NSSecureCoding?, _: Error?) in
            let url = Self.url(from: item)
            DispatchQueue.main.async {
                self?.handleLoadedURL(url)
            }
        }
    }

    private func handleLoadedURL(_ url: URL?) {
        guard let url,
              let albumID = AppleMusicURLParser.albumID(from: url),
              let deepLink = MusicWallDeepLink.addAlbumURL(albumID: albumID)
        else {
            finish()
            return
        }

        extensionContext?.open(deepLink) { [weak self] _ in
            DispatchQueue.main.async {
                self?.finish()
            }
        }
    }

    private static func url(from item: NSSecureCoding?) -> URL? {
        if let url = item as? URL {
            return url
        }
        if let string = item as? String {
            return URL(string: string)
        }
        if let data = item as? Data {
            return URL(dataRepresentation: data, relativeTo: nil)
        }
        return nil
    }

    private func finish() {
        extensionContext?.completeRequest(returningItems: nil)
    }
}

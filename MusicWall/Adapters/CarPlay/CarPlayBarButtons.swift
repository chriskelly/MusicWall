import CarPlay
import UIKit

enum CarPlayBarButtons {
    static func shuffle(handler: @escaping @MainActor (CPBarButton) -> Void) -> CPBarButton {
        imageButton(systemName: "shuffle", handler: handler)
    }

    private static func symbolImage(_ name: String) -> UIImage {
        UIImage(systemName: name) ?? UIImage()
    }

    private static func imageButton(
        systemName: String,
        handler: @escaping @MainActor (CPBarButton) -> Void
    ) -> CPBarButton {
        CPBarButton(image: symbolImage(systemName)) { button in
            Task { @MainActor in
                handler(button)
            }
        }
    }
}

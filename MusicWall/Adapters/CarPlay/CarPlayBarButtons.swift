import CarPlay
import UIKit

@MainActor
enum CarPlayBarButtons {
    static func shuffle(handler: @escaping @MainActor (CPBarButton) -> Void) -> CPBarButton {
        imageButton(image: shuffleImage(), handler: handler)
    }

    static func shuffleImage() -> UIImage {
        symbolImage("shuffle")
    }

    static func shuffleBusyImage() -> UIImage {
        symbolImage("clock.arrow.trianglehead.clockwise.rotate.90.path.dotted")
    }

    private static func symbolImage(_ name: String) -> UIImage {
        UIImage(systemName: name) ?? UIImage()
    }

    private static func imageButton(
        image: UIImage,
        handler: @escaping @MainActor (CPBarButton) -> Void
    ) -> CPBarButton {
        CPBarButton(image: image) { button in
            MainActor.assumeIsolated {
                handler(button)
            }
        }
    }
}

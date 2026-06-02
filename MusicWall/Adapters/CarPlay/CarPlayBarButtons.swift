import CarPlay
import UIKit

enum CarPlayBarButtons {
    static func shuffle(handler: @escaping @MainActor (CPBarButton) -> Void) -> CPBarButton {
        imageButton(systemName: "shuffle", handler: handler)
    }

    static func forward(handler: @escaping @MainActor (CPBarButton) -> Void) -> CPBarButton {
        imageButton(systemName: "chevron.right", handler: handler)
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

    /// Invisible leading placeholder so the title stays centered when only trailing buttons are shown.
    static func layoutSpacer() -> CPBarButton {
        let button = CPBarButton(
            image: symbolImage("shuffle")
                .withRenderingMode(.alwaysTemplate)
                .withTintColor(.clear),
            handler: nil
        )
        button.isEnabled = false
        return button
    }
}

import SwiftUI

struct UITestStateReader: View {
    @Bindable var playback: UITestPlaybackController

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .accessibilityIdentifier("uitest.lastPlayedAlbum")
            .accessibilityValue(playback.lastPlayedAlbumID)
            .accessibilityElement(children: .ignore)
    }
}

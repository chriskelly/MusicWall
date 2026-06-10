import Foundation

enum CarPlayAlbumLibraryPresentation: Equatable {
    case connect
    case shuffle

    var setsRootAnimated: Bool {
        self == .connect
    }

    var loadsArtworkInBackground: Bool {
        self == .connect
    }

    var updatesSectionsInPlace: Bool {
        self == .shuffle
    }
}

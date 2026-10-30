import Foundation

enum AppleMusicURLParser {
    static func albumID(from url: URL) -> String? {
        guard isAppleMusicURL(url) else { return nil }
        guard url.pathComponents.contains(where: { $0 == "album" }) else { return nil }

        if let idPrefixed = idFromPrefixedPath(url.path) {
            return idPrefixed
        }

        for component in url.pathComponents.reversed() {
            if !component.isEmpty, component.allSatisfy(\.isNumber) {
                return component
            }
        }
        return nil
    }

    private static func isAppleMusicURL(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        return host == "music.apple.com" || host == "itunes.apple.com"
    }

    private static func idFromPrefixedPath(_ path: String) -> String? {
        guard let marker = path.range(of: "/id") else { return nil }
        let digits = path[marker.upperBound...].prefix(while: \.isNumber)
        guard !digits.isEmpty else { return nil }
        return String(digits)
    }
}

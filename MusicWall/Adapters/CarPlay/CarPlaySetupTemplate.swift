import CarPlay

enum CarPlaySetupTemplate {
    static func make() -> CPInformationTemplate {
        let item = CPInformationItem(
            title: "MusicWall",
            detail: "Open MusicWall on your iPhone to set up your album wall."
        )
        return CPInformationTemplate(title: "MusicWall", layout: .leading, items: [item], actions: [])
    }
}

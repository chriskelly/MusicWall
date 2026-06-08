import CarPlay

@MainActor
enum CarPlaySetupTemplate {
    static func make() -> CPInformationTemplate {
        let item = CPInformationItem(
            title: CarPlayCopy.appName,
            detail: CarPlayCopy.setupDetail
        )
        return CPInformationTemplate(
            title: CarPlayCopy.appName,
            layout: .leading,
            items: [item],
            actions: []
        )
    }
}

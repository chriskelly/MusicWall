import SwiftUI

struct EmptyAlbumsView: View {
    let onAddAlbum: () -> Void
    let onImport: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "opticaldisc")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            Text("Get started on your Music Wall!")
                .font(.title2)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)

            Text(
                "Every great collection starts with one great album. "
                    + "Search Apple Music, or restore your albums if you're returning."
            )
            .font(.body)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal)

            VStack(spacing: 12) {
                Button("Add an album", action: onAddAlbum)
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("home.emptyWelcome.addAlbum")

                Button("Import a backup", action: onImport)
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("home.emptyWelcome.import")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home.emptyWelcome")
    }
}

#Preview {
    EmptyAlbumsView(onAddAlbum: {}, onImport: {})
}

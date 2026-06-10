import UIKit
import Testing
@testable import MusicWall

@MainActor
struct CarPlayBarButtonsTests {
    @Test
    func shuffleImages_areNonEmptyAndDistinct() {
        let idle = CarPlayBarButtons.shuffleImage()
        let busy = CarPlayBarButtons.shuffleBusyImage()

        #expect(idle.size != .zero)
        #expect(busy.size != .zero)
        #expect(idle != busy)
    }
}

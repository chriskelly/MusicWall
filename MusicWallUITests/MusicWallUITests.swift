import XCTest

@MainActor
final class MusicWallUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testLaunch_savedLibrary_showsFixtureTitles() throws {
        let app = launchApp(scenario: "savedLibrary")
        XCTAssertTrue(app.navigationBars["My Albums"].waitForExistence(timeout: 10))
        assertFixtureAlbumsVisible(in: app)
    }

    func testLaunch_restoreFromBackup_showsFixtureTitles() throws {
        let app = launchApp(scenario: "restoreFromBackup")
        XCTAssertTrue(app.navigationBars["My Albums"].waitForExistence(timeout: 10))
        assertFixtureAlbumsVisible(in: app, timeout: 10)
    }

    func testTapAlbum_invokesPlayback() throws {
        let app = launchApp(scenario: "savedLibrary")
        XCTAssertTrue(app.navigationBars["My Albums"].waitForExistence(timeout: 10))
        assertFixtureAlbumsVisible(in: app)

        let album = app.staticTexts["Take Care"].firstMatch
        XCTAssertTrue(album.waitForExistence(timeout: 10))
        XCTAssertTrue(waitUntilHittable(album, timeout: 10))
        album.tap()

        XCTAssertTrue(
            waitForLastPlayedAlbumID("fixture-drake", in: app, retryTap: album),
            "Expected mock playback to record fixture-drake after album tap"
        )
    }

    func testLaunch_emptyCollection_showsWelcomeAndAddFlow() throws {
        let app = launchApp(scenario: "emptyCollection")
        XCTAssertTrue(app.navigationBars["My Albums"].waitForExistence(timeout: 10))

        let welcome = app.otherElements["home.emptyWelcome"]
        XCTAssertTrue(welcome.waitForExistence(timeout: 10))

        app.buttons["home.emptyWelcome.addAlbum"].tap()
        XCTAssertTrue(app.navigationBars["Find Album"].waitForExistence(timeout: 5))

        app.buttons["search.cancel"].tap()
        XCTAssertTrue(app.navigationBars["My Albums"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.navigationBars["Find Album"].exists)
    }

    func testSearchSheet_openAndDismiss() throws {
        let app = launchApp(scenario: "savedLibrary")
        XCTAssertTrue(app.staticTexts["Take Care"].waitForExistence(timeout: 10))

        app.buttons["home.addAlbum"].tap()
        XCTAssertTrue(app.navigationBars["Find Album"].waitForExistence(timeout: 5))

        app.buttons["search.cancel"].tap()
        XCTAssertTrue(app.navigationBars["My Albums"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.navigationBars["Find Album"].exists)
    }

    // MARK: - Helpers

    private func launchApp(scenario: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-UITestMockMusic", "-UITestLoadScenario", scenario]
        app.launch()
        return app
    }

    private func assertFixtureAlbumsVisible(
        in app: XCUIApplication,
        timeout: TimeInterval = 5,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertTrue(app.staticTexts["Take Care"].waitForExistence(timeout: timeout), file: file, line: line)
        XCTAssertTrue(app.staticTexts["Born Sinners"].waitForExistence(timeout: timeout), file: file, line: line)
        XCTAssertTrue(
            app.staticTexts["Good Kid, m.A.A.d City"].waitForExistence(timeout: timeout),
            file: file,
            line: line
        )
    }

    private func waitUntilHittable(_ element: XCUIElement, timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate(format: "isHittable == true")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }

    /// Polls the hidden playback bridge; retries one tap if CI is slow to register the gesture.
    private func waitForLastPlayedAlbumID(
        _ expectedID: String,
        in app: XCUIApplication,
        retryTap: XCUIElement?,
        timeout: TimeInterval = 45
    ) -> Bool {
        let bridge = app.otherElements["uitest.lastPlayedAlbum"]
        guard bridge.waitForExistence(timeout: 15) else { return false }

        let pollInterval: TimeInterval = 0.25
        let retryAfter: TimeInterval = 5
        var retryTapCount = 0
        let maxRetryTaps = 2
        let start = Date()
        let deadline = start.addingTimeInterval(timeout)

        while Date() < deadline {
            if (bridge.value as? String) == expectedID {
                return true
            }

            if let retryTap,
               retryTapCount < maxRetryTaps,
               Date().timeIntervalSince(start) >= retryAfter * Double(retryTapCount + 1) {
                retryTap.tap()
                retryTapCount += 1
            }

            RunLoop.current.run(until: Date().addingTimeInterval(pollInterval))
        }

        return (bridge.value as? String) == expectedID
    }
}

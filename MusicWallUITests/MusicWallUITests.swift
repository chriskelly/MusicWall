import XCTest

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
        let album = app.staticTexts["Take Care"]
        XCTAssertTrue(album.waitForExistence(timeout: 10))
        album.tap()

        let bridge = app.otherElements["uitest.lastPlayedAlbum"]
        XCTAssertTrue(bridge.waitForExistence(timeout: 5))
        let predicate = NSPredicate(format: "value == %@", "fixture-drake")
        let expectation = expectation(for: predicate, evaluatedWith: bridge)
        wait(for: [expectation], timeout: 5)
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
}

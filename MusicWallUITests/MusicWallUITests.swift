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
}

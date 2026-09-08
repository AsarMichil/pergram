import XCTest

/// Drives the app into the states worth showing on the App Store and attaches a screenshot of each.
/// Not a correctness test: it asserts only enough to fail loudly if a screen it needs is missing.
///
/// Each verdict starts from a fresh launch, because the selected item is view state rather than
/// stored, so relaunching is what clears it.
final class ScreenshotTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testCaptureStoreScreenshots() {
        let app = launch()
        app.buttons["Items"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Items"].waitForExistence(timeout: 5))
        capture("04-items")

        captureVerdict(item: "Bananas", price: "1", named: "01-good")
        captureVerdict(item: "Ground beef (lean)", price: "15", named: "02-meh")
        captureVerdict(item: "Cheddar cheese", price: "30", named: "03-bad")
    }

    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-checkDisplayUnit", "kilogram", "-checkAmountUnit", "kilogram"]
        app.launch()
        return app
    }

    private func captureVerdict(item: String, price: String, named name: String) {
        let app = launch()

        app.buttons["No item selected"].firstMatch.tap()
        let row = app.staticTexts[item].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5), "no picker row for \(item)")
        row.tap()

        for digit in price { app.buttons[String(digit)].firstMatch.tap() }
        app.staticTexts["0"].firstMatch.tap()
        app.buttons["1"].firstMatch.tap()

        capture(name)
    }

    private func capture(_ name: String) {
        Thread.sleep(forTimeInterval: 1.5)
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }
}

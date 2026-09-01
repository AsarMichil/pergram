import XCTest

/// Drives the app into the states worth showing on the App Store and attaches a screenshot of each.
/// Not a correctness test: it asserts only enough to fail loudly if a screen it needs is missing.
final class ScreenshotTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = [
            "-checkDisplayUnit", "kilogram",
            "-checkAmountUnit", "kilogram",
        ]
        app.launch()
    }

    func testCaptureStoreScreenshots() {
        capture("03-items", after: openItems)
        capture("02-meh", after: enterMehPricedItem)
    }

    private func openItems() {
        app.buttons["Items"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Items"].waitForExistence(timeout: 5))
    }

    private func enterMehPricedItem() {
        app.buttons["Check"].firstMatch.tap()
        app.buttons["No item selected"].firstMatch.tap()

        let beef = app.staticTexts["Ground beef (lean)"].firstMatch
        XCTAssertTrue(beef.waitForExistence(timeout: 5))
        beef.tap()

        tapKeys("15")
        app.staticTexts["0"].firstMatch.tap()
        tapKeys("1")
    }

    private func tapKeys(_ digits: String) {
        for digit in digits {
            app.buttons[String(digit)].firstMatch.tap()
        }
    }

    private func capture(_ name: String, after steps: () -> Void) {
        steps()
        Thread.sleep(forTimeInterval: 1.5)
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }
}

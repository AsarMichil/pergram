import XCTest

/// The Guideline 4 rejection was a fixed column overflowing a short screen: the mode toggle fell off
/// the top and the bottom keypad row hid behind the floating tab bar. Run on the shortest supported
/// iPhone, these fail if either comes back.
///
/// `isHittable` is the assertion that matters — an element clipped off-screen or covered by the tab
/// bar still *exists*, so `exists` would pass while the control is unusable.
final class ShortScreenTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launch()
        return app
    }

    func testCheckScreenFitsWithoutClipping() {
        let app = launch()

        let scanToggle = app.buttons["Switch to Scan"].firstMatch
        XCTAssertTrue(scanToggle.waitForExistence(timeout: 5), "no mode toggle")
        XCTAssertTrue(scanToggle.isHittable, "mode toggle is clipped off the top")

        XCTAssertTrue(app.buttons["itemRow"].firstMatch.isHittable, "item row is not reachable")

        let zeroKey = app.buttons["0"].firstMatch
        XCTAssertTrue(zeroKey.isHittable, "bottom keypad row is behind the tab bar")

        for digit in ["1", "4", "7"] {
            XCTAssertTrue(app.buttons[digit].firstMatch.isHittable, "\(digit) key is not reachable")
        }
    }

    func testBookmarkKeyStaysReachableOnceAPriceIsEntered() {
        let app = launch()

        app.buttons["2"].firstMatch.tap()
        app.descendants(matching: .any).matching(identifier: "amountField").firstMatch.tap()
        app.buttons["1"].firstMatch.tap()

        let bookmark = app.buttons["bookmarkKey"].firstMatch
        XCTAssertTrue(bookmark.isHittable, "bookmark key is behind the tab bar")

        bookmark.tap()

        // Parking a price must not push the keypad off the bottom.
        XCTAssertTrue(app.buttons["0"].firstMatch.isHittable, "keypad shifted under the tab bar")
        XCTAssertTrue(bookmark.isHittable, "bookmark key moved out of reach")
    }

    /// The compact tier draws 36pt keys. If the borrowed grid gap ever stops reaching the touch
    /// system, these frames come back at the drawn size and the keypad quietly breaks the minimum.
    func testKeyTargetsStayLegalEvenThoughKeysDrawSmaller() {
        let app = launch()

        for identifier in ["1", "5", "9", "0"] {
            let key = app.buttons[identifier].firstMatch
            XCTAssertTrue(key.waitForExistence(timeout: 5), "no \(identifier) key")
            XCTAssertGreaterThanOrEqual(
                key.frame.height, 44,
                "\(identifier) key target is \(key.frame.height)pt, under the 44pt minimum"
            )
        }
    }

    /// Scan is half the app and swaps the whole input zone out. Its unavailable-camera panel is
    /// greedy (`maxHeight: .infinity`), which is exactly the shape that can confuse tier selection.
    func testScanModeFitsAndCanBeLeft() {
        let app = launch()

        let toScan = app.buttons["Switch to Scan"].firstMatch
        XCTAssertTrue(toScan.waitForExistence(timeout: 5), "no scan toggle")
        toScan.tap()

        let toType = app.buttons["Switch to Type"].firstMatch
        XCTAssertTrue(toType.waitForExistence(timeout: 5), "scan mode has no way back")
        XCTAssertTrue(toType.isHittable, "the way back out of scan is clipped or covered")

        toType.tap()
        XCTAssertTrue(app.buttons["0"].firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["0"].firstMatch.isHittable, "keypad broke after returning")
    }

    func testItemPickerAndGoodPriceSheetsAreUsable() {
        let app = launch()

        app.buttons["itemRow"].firstMatch.tap()
        let chooseItem = app.buttons["chooseItem"].firstMatch
        XCTAssertTrue(chooseItem.waitForExistence(timeout: 5), "item menu did not open")
        chooseItem.tap()

        let bananas = app.staticTexts["Bananas"].firstMatch
        XCTAssertTrue(bananas.waitForExistence(timeout: 5), "picker has no rows")
        XCTAssertTrue(bananas.isHittable, "picker rows are not reachable")
        bananas.tap()

        XCTAssertTrue(app.buttons["0"].firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["0"].firstMatch.isHittable, "keypad broke after the picker")
    }

    func testAddItemSheetFitsWithoutClipping() {
        let app = launch()

        app.buttons["Items"].firstMatch.tap()
        let add = app.buttons["addItem"].firstMatch
        XCTAssertTrue(add.waitForExistence(timeout: 5), "no add button")
        add.tap()

        let zeroKey = app.buttons["0"].firstMatch
        XCTAssertTrue(zeroKey.waitForExistence(timeout: 5), "sheet keypad never appeared")
        XCTAssertTrue(zeroKey.isHittable, "sheet keypad is clipped")
        XCTAssertTrue(app.buttons["Save"].firstMatch.isHittable, "sheet Save is not reachable")
    }
}

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

    func testAddToCartKeyIsReachableAndCarriesTheTotalToShop() {
        let app = launch()

        app.buttons["4"].firstMatch.tap()
        let addToCart = app.buttons["addToCartKey"].firstMatch
        XCTAssertTrue(addToCart.isHittable, "add-to-cart key is behind the tab bar")
        addToCart.tap()

        let shopChip = app.buttons
            .matching(NSPredicate(format: "label BEGINSWITH 'Switch to Shop, cart'"))
            .firstMatch
        XCTAssertTrue(shopChip.waitForExistence(timeout: 5), "the Shop chip shows no total")
        XCTAssertTrue(shopChip.isHittable, "the Shop chip is clipped")
        XCTAssertTrue(app.buttons["0"].firstMatch.isHittable, "keypad shifted under the tab bar")

        shopChip.tap()
        XCTAssertTrue(app.staticTexts["cartTotal"].waitForExistence(timeout: 5), "no cart total")

        let finish = app.buttons["finishTrip"].firstMatch
        if !finish.isHittable { app.swipeUp() }
        XCTAssertTrue(finish.isHittable, "Finish trip is not reachable")
        finish.tap()
        let confirm = app.buttons["confirmFinishTrip"].firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 5), "no trip summary")
        confirm.tap()

        XCTAssertTrue(app.buttons["Switch to Type"].firstMatch.isHittable, "Shop has no way back")
    }

    func testScanActionsFitBesideTheCaption() {
        let app = launch()

        app.buttons["Switch to Scan"].firstMatch.tap()

        for identifier in ["scanBookmark", "scanAddToCart"] {
            let button = app.buttons[identifier].firstMatch
            XCTAssertTrue(button.waitForExistence(timeout: 5), "no \(identifier)")
            XCTAssertTrue(button.isHittable, "\(identifier) is clipped or covered")
        }
        XCTAssertTrue(app.buttons["Switch to Type"].firstMatch.isHittable)
    }

    /// Shop is the leftmost mode, so its rows keep their actions on the leading edge and a swipe left
    /// anywhere on the page, row or not, goes back to Type.
    func testSwipingLeftOnShopReturnsToTypeFromARowOrTheBackground() {
        let app = launch()

        app.buttons["7"].firstMatch.tap()
        app.buttons["addToCartKey"].firstMatch.tap()
        let shopChip = app.buttons
            .matching(NSPredicate(format: "label BEGINSWITH 'Switch to Shop'"))
            .firstMatch
        let zero = app.buttons["0"].firstMatch

        shopChip.tap()
        let label = app.staticTexts
            .matching(NSPredicate(format: "label BEGINSWITH 'Item '"))
            .firstMatch
        XCTAssertTrue(label.waitForExistence(timeout: 5), "no cart row")
        drag(label, from: 0.1, to: 0.9)
        XCTAssertTrue(
            app.buttons["Remove"].firstMatch.waitForExistence(timeout: 5), "no row actions")
        drag(label, from: 0.9, to: 0.1)
        XCTAssertTrue(zero.waitForExistence(timeout: 5), "a swipe on a row did not leave Shop")

        shopChip.tap()
        XCTAssertTrue(app.staticTexts["cartTotal"].waitForExistence(timeout: 5))
        drag(app.staticTexts["cartTotal"].firstMatch, from: 0.9, to: 0.1)
        XCTAssertTrue(zero.waitForExistence(timeout: 5), "a swipe on the page did not leave Shop")

        shopChip.tap()
        let finish = app.buttons["finishTrip"].firstMatch
        if !finish.isHittable { app.swipeUp() }
        finish.tap()
        app.buttons["confirmFinishTrip"].firstMatch.tap()
    }

    /// Across the screen rather than across the element: a short element's own `swipeRight()` covers
    /// too little distance and lands as a tap.
    private func drag(_ element: XCUIElement, from start: CGFloat, to end: CGFloat) {
        let window = XCUIApplication().windows.firstMatch
        let y = element.frame.midY / window.frame.height
        window.coordinate(withNormalizedOffset: CGVector(dx: start, dy: y))
            .press(
                forDuration: 0.05,
                thenDragTo: window.coordinate(withNormalizedOffset: CGVector(dx: end, dy: y)))
    }
}

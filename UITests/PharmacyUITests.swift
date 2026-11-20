import XCTest

final class PharmacyUITests: XCTestCase {
    func testAddressSearchFindsNearestWithoutLocationPermission() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]
        app.launch()
        let search = app.textFields["address-input"]
        XCTAssertTrue(search.waitForExistence(timeout: 10))
        search.tap()
        search.typeText("Helsinki")
        app.buttons["search-address"].tap()
        let place = app.buttons["place-helsinki"]
        XCTAssertTrue(place.waitForExistence(timeout: 5))
        place.tap()
        app.swipeUp()
        XCTAssertTrue(app.staticTexts["Keskustan Apteekki"].firstMatch.waitForExistence(timeout: 5))
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Address search results"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    func testDeniedLocationExplainsManualAlternative() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-location-denied"]
        app.launch()
        app.buttons["use-location"].tap()
        XCTAssertTrue(app.buttons["Avaa Asetukset"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.textFields["address-input"].exists)
        XCTAssertTrue(app.buttons["search-address"].isEnabled)
    }
}

import XCTest

final class ScanUITests: XCTestCase {
    @MainActor
    func testDemoScanControlsAndLayers() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--demo"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Demo surface"].waitForExistence(timeout: 15))
        app.buttons["Pause Scan"].tap()
        XCTAssertTrue(app.buttons["Resume Scan"].exists)
        XCTAssertTrue(app.staticTexts["Demo paused"].exists)
        let slider = app.sliders["Demo viewpoint"]
        slider.adjust(toNormalizedSliderPosition: 0.7)
        XCTAssertTrue(app.staticTexts["Demo paused"].exists)
        app.buttons["Layers"].tap()
        XCTAssertTrue(app.navigationBars["Display layers"].waitForExistence(timeout: 5))
        app.swipeUp()
        let spacing = app.sliders["Dot spacing"]
        for _ in 0..<3 where !spacing.isHittable { app.swipeUp() }
        XCTAssertTrue(spacing.waitForExistence(timeout: 5))
        spacing.adjust(toNormalizedSliderPosition: 1)
        // SwiftUI groups the LabeledContent row in accessibility; verify the
        // slider’s explicit accessible value and the main screen value below.
        XCTAssertEqual(spacing.value as? String, "30 centimeters")
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Display layers"
        attachment.lifetime = .keepAlways
        add(attachment)
        app.buttons["Done"].tap()
        XCTAssertTrue(app.buttons["Resume Scan"].waitForExistence(timeout: 5))
        app.buttons["Resume Scan"].tap()
        XCTAssertTrue(app.buttons["Pause Scan"].exists)
        app.buttons["Reset"].tap()
        XCTAssertTrue(app.staticTexts["Demo surface"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["30 cm grid"].exists)
        let preview = XCTAttachment(screenshot: app.screenshot())
        preview.name = "Surface preview"
        preview.lifetime = .keepAlways
        add(preview)
    }


    @MainActor
    func testSaveViewerHistoryAndCameraControls() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--demo"]
        app.launch()
        XCTAssertTrue(app.buttons["Save"].waitForExistence(timeout: 10))
        app.buttons["Layers"].tap()
        let live = app.switches["Live camera"]
        XCTAssertTrue(live.waitForExistence(timeout: 5))
        live.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        let off = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", "0"), object: live)
        XCTAssertEqual(XCTWaiter.wait(for: [off], timeout: 3), .completed)
        live.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        app.sliders["Camera opacity"].adjust(toNormalizedSliderPosition: 0)
        XCTAssertEqual(app.sliders["Camera opacity"].value as? String, "0 percent")
        app.buttons["Done"].tap()
        app.buttons["Save"].tap()
        XCTAssertTrue(app.navigationBars["Saved surface"].waitForExistence(timeout: 15))
        let initial = XCTAttachment(screenshot: app.screenshot())
        initial.name = "Saved initial"
        initial.lifetime = .keepAlways
        add(initial)
        app.buttons["Zoom in"].tap()
        app.buttons["Zoom out"].tap()
        app.buttons["Fit"].tap()
        let canvas = app.otherElements["Saved terrain canvas"]
        let start = canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.4, dy: 0.4))
        start.press(forDuration: 0.1, thenDragTo: canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.7, dy: 0.45)))
        canvas.pinch(withScale: 1.5, velocity: 1)
        let dots = XCTAttachment(screenshot: app.screenshot())
        dots.name = "Saved scan dots"
        dots.lifetime = .keepAlways
        add(dots)
        app.buttons["Saved layers"].tap()
        XCTAssertFalse(app.switches["Live camera"].exists)
        XCTAssertEqual(app.switches["Elevation contours"].value as? String, "0")
        let contours = app.switches["Elevation contours"]
        contours.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        XCTAssertEqual(contours.value as? String, "1")
        let surface = app.switches["Surface mesh"]
        surface.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        XCTAssertEqual(surface.value as? String, "1")
        app.buttons["Done"].tap()
        let mesh = XCTAttachment(screenshot: app.screenshot())
        mesh.name = "Saved scan contours and mesh"
        mesh.lifetime = .keepAlways
        add(mesh)
        app.buttons["Close"].tap()
        XCTAssertTrue(app.buttons["Resume Scan"].waitForExistence(timeout: 5))
        app.terminate()
        app.launch()
        app.buttons["History"].tap()
        XCTAssertTrue(app.navigationBars["Scan history"].waitForExistence(timeout: 10))
        let row = app.buttons.matching(identifier: "Saved scan row").firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        row.tap()
        XCTAssertTrue(app.navigationBars["Saved surface"].waitForExistence(timeout: 10))
    }

    @MainActor
    func testUnsupportedDeviceOffersExplicitDemo() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.staticTexts["A LiDAR iPhone is needed"].waitForExistence(timeout: 10))
        app.buttons["Explore Demo"].tap()
        XCTAssertTrue(app.staticTexts["Demo surface"].waitForExistence(timeout: 10))
    }
}

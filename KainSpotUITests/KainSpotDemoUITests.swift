//
//  KainSpotDemoUITests.swift
//  KainSpotUITests
//
//  End-to-end UI walkthrough used both as an integration test and as the scripted demo
//  that CI records to video, plus a single-screen screenshot test for the two-device Auto Layout check.
//  Course weeks: Week 8 (testing / E2E integration), exercising Weeks 1–7 screens.
//

import XCTest

final class KainSpotDemoUITests: XCTestCase {

    /// Generous wait so slow CI simulators (first launch, store loading, network sync) do not flake.
    private let timeout: TimeInterval = 15

    /// Button titles iOS uses on permission alerts (location and photos), in order of preference.
    private let allowButtonTitles = ["Allow While Using App", "Allow Once", "Allow", "Allow Full Access", "OK"]

    override func setUpWithError() throws {
        // Stop at the first hard failure so the recording and logs point at the real problem.
        continueAfterFailure = false
    }

    // MARK: - Tests

    /// Scripted demo: Home → Preferences → Spot list → Spot detail → back → Gallery.
    /// sleep() pauses exist only so the CI screen recording is watchable by a human.
    @MainActor
    func testFullDemoWalkthrough() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-uiDemo"]
        registerPermissionMonitor()
        app.launch()

        // 1. Home (Week 1 Auto Layout welcome screen)
        let findButton = app.buttons["findButton"]
        XCTAssertTrue(findButton.waitForExistence(timeout: timeout), "Home screen did not appear")
        sleep(2)
        attachScreenshot(of: app, named: "01-home")
        findButton.tap()

        // 2. Preferences (Week 2 inputs)
        let nicknameField = app.textFields["nicknameField"]
        XCTAssertTrue(nicknameField.waitForExistence(timeout: timeout), "Preferences screen did not appear")
        nicknameField.tap()
        clearText(in: nicknameField)
        nicknameField.typeText("Sis")
        // Return key: the text field delegate dismisses the keyboard so it does not cover the controls.
        nicknameField.typeText("\n")

        let priceSegment = app.segmentedControls["priceSegment"]
        XCTAssertTrue(priceSegment.waitForExistence(timeout: timeout), "Price segment missing")
        let midPrice = priceSegment.buttons["₱₱"]
        if midPrice.waitForExistence(timeout: timeout) {
            midPrice.tap()
        } else {
            // Fallback by position: segments are Any, ₱, ₱₱, ₱₱₱.
            priceSegment.buttons.element(boundBy: 2).tap()
        }

        let trendingSwitch = app.switches["trendingSwitch"]
        XCTAssertTrue(trendingSwitch.waitForExistence(timeout: timeout), "Trending switch missing")
        turnOn(trendingSwitch)

        let distanceSlider = app.sliders["distanceSlider"]
        XCTAssertTrue(distanceSlider.waitForExistence(timeout: timeout), "Distance slider missing")
        // Slide all the way to 15 km so the trending + ₱₱ filter still has spots to show.
        distanceSlider.adjust(toNormalizedSliderPosition: 1.0)
        sleep(1)
        attachScreenshot(of: app, named: "02-preferences")

        let showSpotsButton = app.buttons["showSpotsButton"]
        XCTAssertTrue(showSpotsButton.waitForExistence(timeout: timeout), "Show Spots button missing")
        showSpotsButton.tap()

        // 3. Spot list (Weeks 3 + 5: table view, Core Data, networking)
        let table = app.tables["spotsTable"]
        XCTAssertTrue(table.waitForExistence(timeout: timeout), "Spot list did not appear")
        let firstCell = table.cells.firstMatch
        let hasSpots = firstCell.waitForExistence(timeout: timeout)
        sleep(2)
        attachScreenshot(of: app, named: "03-spot-list")

        if hasSpots {
            table.swipeUp()
            sleep(1)
            table.swipeDown()
            sleep(1)
            firstCell.tap()

            // 4. Spot detail (Week 6: map, location, photo picker)
            let photoButton = app.buttons["photoButton"]
            XCTAssertTrue(photoButton.waitForExistence(timeout: timeout), "Spot detail did not appear")
            // The location prompt usually appears here; a harmless tap on the nav bar lets the
            // interruption monitor fire, and the springboard check covers monitors that never fire.
            sleep(1)
            app.navigationBars.firstMatch.tap()
            dismissSpringboardPermissionAlertIfNeeded()
            sleep(2)
            attachScreenshot(of: app, named: "04-spot-detail")

            let scrollView = app.scrollViews.firstMatch
            if scrollView.waitForExistence(timeout: timeout) {
                scrollView.swipeUp()
                sleep(2)
                scrollView.swipeDown()
                sleep(1)
            }

            goBack(in: app) // detail → list
            XCTAssertTrue(table.waitForExistence(timeout: timeout), "Did not return to the spot list")
        }

        goBack(in: app) // list → preferences
        XCTAssertTrue(nicknameField.waitForExistence(timeout: timeout), "Did not return to preferences")
        goBack(in: app) // preferences → home

        // 5. Gallery (Week 7: shared PhotoStore utility)
        let galleryButton = app.buttons["galleryButton"]
        XCTAssertTrue(galleryButton.waitForExistence(timeout: timeout), "Did not return to home")
        galleryButton.tap()

        let gallery = app.collectionViews["galleryGrid"]
        XCTAssertTrue(gallery.waitForExistence(timeout: timeout), "Gallery did not appear")
        sleep(2)
        attachScreenshot(of: app, named: "05-gallery")
    }

    /// Launch-only screenshot. CI runs it on a small (iPhone SE) and a large (iPhone 16 Pro)
    /// simulator so the two images prove the Home Auto Layout adapts to both screen sizes.
    @MainActor
    func testHomeScreenshot() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.buttons["findButton"].waitForExistence(timeout: timeout), "Home screen did not appear")
        XCTAssertTrue(app.buttons["galleryButton"].waitForExistence(timeout: timeout), "Gallery button missing")
        sleep(1)
        attachScreenshot(of: app, named: "home")
    }

    // MARK: - Helpers

    /// Auto-answers system permission alerts (location / photos). Monitors only fire on the
    /// next interaction with the app, which is why the walkthrough taps after the alert can appear.
    @MainActor
    private func registerPermissionMonitor() {
        let titles = allowButtonTitles
        addUIInterruptionMonitor(withDescription: "System permission alert") { alert in
            for title in titles {
                let button = alert.buttons[title]
                if button.exists {
                    button.tap()
                    return true
                }
            }
            return false
        }
    }

    /// Belt-and-braces fallback: on some iOS versions the location alert is owned by
    /// SpringBoard and the interruption monitor never triggers, so tap it directly.
    @MainActor
    private func dismissSpringboardPermissionAlertIfNeeded() {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let alert = springboard.alerts.firstMatch
        guard alert.waitForExistence(timeout: 2) else { return }
        for title in allowButtonTitles {
            let button = alert.buttons[title]
            if button.exists {
                button.tap()
                return
            }
        }
    }

    /// Removes any nickname pre-filled from UserPrefs so the typed value is exactly "Sis".
    @MainActor
    private func clearText(in field: XCUIElement) {
        guard let current = field.value as? String, !current.isEmpty else { return }
        // When empty, value returns the placeholder text; deleting it would be a no-op anyway.
        if let placeholder = field.placeholderValue, current == placeholder { return }
        let deletes = String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count)
        field.typeText(deletes)
    }

    /// Switches report "1"/"0" as their value. A plain tap can miss the thumb on some
    /// simulators, so retry once on the switch's right edge if the value did not change.
    @MainActor
    private func turnOn(_ toggle: XCUIElement) {
        if isOn(toggle) { return }
        toggle.tap()
        if !isOn(toggle) {
            toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        }
    }

    @MainActor
    private func isOn(_ toggle: XCUIElement) -> Bool {
        return (toggle.value as? String) == "1"
    }

    /// Taps the navigation bar's back button (always the first button in the bar).
    @MainActor
    private func goBack(in app: XCUIApplication) {
        let backButton = app.navigationBars.buttons.element(boundBy: 0)
        if backButton.waitForExistence(timeout: timeout) {
            backButton.tap()
        }
        sleep(1)
    }

    /// Keeps a named screenshot in the .xcresult even when the test passes, so CI can export it.
    @MainActor
    private func attachScreenshot(of app: XCUIApplication, named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

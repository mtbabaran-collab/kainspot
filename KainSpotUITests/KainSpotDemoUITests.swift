//
//  KainSpotDemoUITests.swift
//  KainSpotUITests
//
//  End-to-end UI walkthrough used both as an integration test and as the scripted demo
//  that CI records to video, plus a single-screen screenshot test for the two-device Auto Layout check.
//  Course weeks: Week 8 (testing / E2E integration), exercising Weeks 1–7 screens.
//  Feature: full product tour (chips, Plan your vacant, smart list, search, roulette, detail, Ask, Gallery, Settings).
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

    /// Scripted demo, paced slowly (2–3 s pauses) so the CI screen recording is watchable:
    /// Home → 🍜 chip → Plan your vacant → smart list → search → 🎰 roulette → detail → Home →
    /// Ask Kain Spot → Gallery → Settings. Optional steps are guarded so the tour always finishes.
    @MainActor
    func testFullDemoWalkthrough() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-uiDemo"]
        // CI passes the Gemini key as TEST_RUNNER_GEMINI_API_KEY; forward it so the app can use real AI in the demo.
        if let key = ProcessInfo.processInfo.environment["GEMINI_API_KEY"], !key.isEmpty {
            app.launchEnvironment["GEMINI_API_KEY"] = key
        }
        registerPermissionMonitor()
        app.launch()

        // 1. Home (Week 1 Auto Layout welcome screen + category chips)
        let findButton = app.buttons["findButton"]
        XCTAssertTrue(findButton.waitForExistence(timeout: timeout), "Home screen did not appear")
        sleep(3)
        attachScreenshot(of: app, named: "01-home")

        let kainChip = app.buttons["chipKain"]
        if kainChip.waitForExistence(timeout: 3) && kainChip.isHittable {
            kainChip.tap()
        } else {
            findButton.tap()
        }

        // 2. Plan your vacant (Week 2 inputs + Vacant Planner controls)
        let nicknameField = app.textFields["nicknameField"]
        XCTAssertTrue(nicknameField.waitForExistence(timeout: timeout), "Plan your vacant screen did not appear")
        sleep(2)
        nicknameField.tap()
        clearText(in: nicknameField)
        nicknameField.typeText("Sis")
        // Return key: the text field delegate dismisses the keyboard so it does not cover the controls.
        nicknameField.typeText("\n")
        sleep(1)

        let kindSegment = app.segmentedControls["kindSegment"]
        if kindSegment.waitForExistence(timeout: 5) {
            let kain = kindSegment.buttons["Kain"]
            if kain.exists {
                kain.tap()
            } else {
                // Segments are All, Kain, Tambay, Galaw, Gala.
                kindSegment.buttons.element(boundBy: 1).tap()
            }
            sleep(1)
        }

        let vacantSlider = app.sliders["vacantSlider"]
        if vacantSlider.waitForExistence(timeout: 5) {
            scrollIntoView(vacantSlider, in: app)
            // 30–240 min: ~0.43 lands near 120 min (a typical long vacant) after snapping to 15-minute steps.
            vacantSlider.adjust(toNormalizedSliderPosition: 0.43)
            sleep(1)
        }

        let budgetSlider = app.sliders["budgetSlider"]
        if budgetSlider.waitForExistence(timeout: 5) {
            scrollIntoView(budgetSlider, in: app)
            // ₱0–₱1000: 0.3 snaps to about ₱300.
            budgetSlider.adjust(toNormalizedSliderPosition: 0.3)
            sleep(1)
        }

        // Shown but left OFF: no bundled spot is marked student_discount yet, and the switch is a hard
        // filter, so turning it on would empty the list. (The safety net below still covers a saved "on".)
        let discountSwitch = app.switches["discountSwitch"]
        if discountSwitch.waitForExistence(timeout: 5) {
            scrollIntoView(discountSwitch, in: app)
            turnOff(discountSwitch)
            sleep(1)
        }

        // Keep the older filters wide so the demo always has spots to show.
        let priceSegment = app.segmentedControls["priceSegment"]
        if priceSegment.waitForExistence(timeout: 3) {
            scrollIntoView(priceSegment, in: app)
            priceSegment.buttons.element(boundBy: 0).tap() // "Any"
        }
        let distanceSlider = app.sliders["distanceSlider"]
        if distanceSlider.waitForExistence(timeout: 3) {
            scrollIntoView(distanceSlider, in: app)
            distanceSlider.adjust(toNormalizedSliderPosition: 1.0)
        }
        sleep(2)
        attachScreenshot(of: app, named: "02-plan")

        let showSpotsButton = app.buttons["showSpotsButton"]
        XCTAssertTrue(showSpotsButton.waitForExistence(timeout: timeout), "Show Spots button missing")
        scrollIntoView(showSpotsButton, in: app)
        showSpotsButton.tap()

        // 3. Smart list (Weeks 3 + 5: table view, Core Data, networking + SmartRanker)
        let table = app.tables["spotsTable"]
        XCTAssertTrue(table.waitForExistence(timeout: timeout), "Spot list did not appear")
        var firstCell = table.cells.firstMatch
        var hasSpots = firstCell.waitForExistence(timeout: timeout)
        if !hasSpots {
            // Safety net for the recording: if no spot offers a student discount, go back,
            // switch the discount filter off and try again so the rest of the tour has spots.
            goBack(in: app)
            if discountSwitch.waitForExistence(timeout: 5) {
                scrollIntoView(discountSwitch, in: app)
                turnOff(discountSwitch)
            }
            if showSpotsButton.waitForExistence(timeout: timeout) {
                scrollIntoView(showSpotsButton, in: app)
                showSpotsButton.tap()
            }
            XCTAssertTrue(table.waitForExistence(timeout: timeout), "Spot list did not reappear")
            firstCell = table.cells.firstMatch
            hasSpots = firstCell.waitForExistence(timeout: timeout)
        }
        sleep(3)
        attachScreenshot(of: app, named: "03-list")

        if hasSpots {
            table.swipeUp()
            sleep(2)
            table.swipeDown()
            sleep(1)
        }

        // 4. Live search ("kape wifi" → QueryParser + SmartRanker)
        let searchField = app.searchFields["spotSearch"].exists
            ? app.searchFields["spotSearch"]
            : app.searchFields.firstMatch
        if searchField.waitForExistence(timeout: 5) {
            searchField.tap()
            searchField.typeText("kape wifi")
            sleep(3)
            attachScreenshot(of: app, named: "04-search")
            let cancel = app.buttons["Cancel"]
            if cancel.waitForExistence(timeout: 3) {
                cancel.tap()
            }
            sleep(1)
        }

        // 5. Kain Roulette 🎰 → Let's go! → detail
        var reachedDetail = false
        let rouletteButton = app.buttons["rouletteButton"]
        if hasSpots && rouletteButton.waitForExistence(timeout: 5) {
            rouletteButton.tap()
            let spinAgain = app.buttons["spinAgainButton"]
            if spinAgain.waitForExistence(timeout: timeout) {
                sleep(4) // the first spin runs ~2.5 s, then confetti
                attachScreenshot(of: app, named: "05-roulette")
                if spinAgain.isEnabled {
                    spinAgain.tap()
                    sleep(4)
                }
                let letsGo = app.buttons["letsGoButton"]
                if letsGo.waitForExistence(timeout: 5) && letsGo.isEnabled {
                    letsGo.tap()
                    reachedDetail = app.buttons["photoButton"].waitForExistence(timeout: timeout)
                } else {
                    let close = app.buttons["rouletteCloseButton"]
                    if close.exists { close.tap() }
                }
            }
        }
        // Fallback: if the roulette couldn't open a spot, tap the first card instead.
        if !reachedDetail && hasSpots && firstCell.waitForExistence(timeout: 5) {
            firstCell.tap()
            reachedDetail = app.buttons["photoButton"].waitForExistence(timeout: timeout)
        }

        // 6. Spot detail (Week 6: map, location, photo picker + amenities, leave-by, emoji pins)
        if reachedDetail {
            // The location prompt usually appears here; a harmless tap on the nav bar lets the
            // interruption monitor fire, and the springboard check covers monitors that never fire.
            sleep(1)
            app.navigationBars.firstMatch.tap()
            dismissSpringboardPermissionAlertIfNeeded()
            sleep(2)
            attachScreenshot(of: app, named: "06-detail")

            let scrollView = app.scrollViews.firstMatch
            if scrollView.waitForExistence(timeout: timeout) {
                scrollView.swipeUp()
                sleep(3) // map + dashed route + Get Directions
                scrollView.swipeDown()
                sleep(1)
            }
        }

        // Back to Home through the navigation back buttons.
        returnHome(in: app, findButton: findButton)
        XCTAssertTrue(findButton.waitForExistence(timeout: timeout), "Did not return to Home")
        sleep(1)

        // 7. Ask Kain Spot ✨ (Gemini when a key exists, offline smart picks otherwise)
        let askButton = app.buttons["askButton"]
        if askButton.waitForExistence(timeout: 5) {
            askButton.tap()
            let suggestion = app.buttons["suggestion0"]
            if suggestion.waitForExistence(timeout: timeout) {
                sleep(2)
                suggestion.tap()
                sleep(1)
                let send = app.buttons["askSendButton"]
                if send.waitForExistence(timeout: 5) {
                    send.tap()
                    _ = app.staticTexts["askSummary"].waitForExistence(timeout: 25)
                }
            }
            sleep(3)
            attachScreenshot(of: app, named: "07-ask")
            goBack(in: app)
        }

        // 8. Gallery (Week 7: shared PhotoStore utility)
        let galleryButton = app.buttons["galleryButton"]
        XCTAssertTrue(galleryButton.waitForExistence(timeout: timeout), "Did not return to Home before Gallery")
        galleryButton.tap()
        let gallery = app.collectionViews["galleryGrid"]
        XCTAssertTrue(gallery.waitForExistence(timeout: timeout), "Gallery did not appear")
        sleep(3)
        attachScreenshot(of: app, named: "08-gallery")
        goBack(in: app)

        // 9. Settings (Gemini key, refresh, about)
        let settingsButton = app.buttons["settingsButton"]
        if settingsButton.waitForExistence(timeout: timeout) {
            settingsButton.tap()
            _ = app.secureTextFields["geminiKeyField"].waitForExistence(timeout: timeout)
            sleep(3)
            attachScreenshot(of: app, named: "09-settings")
        }
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

    /// The Plan screen scrolls on small phones; swipe up a little until the control can be touched.
    @MainActor
    private func scrollIntoView(_ element: XCUIElement, in app: XCUIApplication) {
        var attempts = 0
        while !element.isHittable && attempts < 4 {
            app.scrollViews.firstMatch.swipeUp()
            attempts += 1
        }
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

    /// Mirror of `turnOn`, used by the empty-results safety net.
    @MainActor
    private func turnOff(_ toggle: XCUIElement) {
        if !isOn(toggle) { return }
        toggle.tap()
        if isOn(toggle) {
            toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        }
    }

    @MainActor
    private func isOn(_ toggle: XCUIElement) -> Bool {
        return (toggle.value as? String) == "1"
    }

    /// Taps the navigation bar's back button (always the first button in the bar on pushed screens).
    @MainActor
    private func goBack(in app: XCUIApplication) {
        let backButton = app.navigationBars.buttons.element(boundBy: 0)
        if backButton.waitForExistence(timeout: timeout) {
            backButton.tap()
        }
        sleep(1)
    }

    /// Pops screen by screen until Home's Find button is on screen (Home is the only screen that has it).
    @MainActor
    private func returnHome(in app: XCUIApplication, findButton: XCUIElement) {
        var attempts = 0
        while !findButton.exists && attempts < 5 {
            goBack(in: app)
            attempts += 1
        }
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

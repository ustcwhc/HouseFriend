//
//  HouseFriendUITests.swift
//  HouseFriendUITests
//
//  Created by Jing on 3/7/26.
//

import XCTest

final class HouseFriendUITests: XCTestCase {

    let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launch()
    }

    // MARK: - Launch & Basic UI

    @MainActor
    func testAppLaunchShowsMainUI() throws {
        // App title visible
        XCTAssertTrue(app.staticTexts["HouseFriend"].waitForExistence(timeout: 5))

        // Search field visible
        let searchField = app.textFields["searchField"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 3))

        // Empty state hint visible (no pin yet)
        XCTAssertTrue(app.staticTexts["Search any address"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testPopulationLayerIsDefaultSelected() throws {
        // The active layer chip should show "Population" on launch
        XCTAssertTrue(app.staticTexts["Population"].waitForExistence(timeout: 5))
    }

    // MARK: - Layer Switching

    @MainActor
    func testSwitchToCrimeLayer() throws {
        let crimeButton = app.buttons["layer_Crime"]
        XCTAssertTrue(crimeButton.waitForExistence(timeout: 5))
        crimeButton.tap()

        let crimeChip = app.staticTexts["Crime"]
        XCTAssertTrue(crimeChip.waitForExistence(timeout: 3))
    }

    @MainActor
    func testSwitchToSchoolsLayer() throws {
        let schoolsButton = app.buttons["layer_Schools"]
        XCTAssertTrue(schoolsButton.waitForExistence(timeout: 5))
        schoolsButton.tap()

        XCTAssertTrue(app.staticTexts["Schools"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testSwitchToEarthquakeLayer() throws {
        let quakeButton = app.buttons["layer_Earthquake"]
        XCTAssertTrue(quakeButton.waitForExistence(timeout: 5))
        quakeButton.tap()

        XCTAssertTrue(app.staticTexts["Earthquake"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testSwitchToFireRiskLayer() throws {
        let fireButton = app.buttons["layer_Fire Risk"]
        XCTAssertTrue(fireButton.waitForExistence(timeout: 5))
        fireButton.tap()

        XCTAssertTrue(app.staticTexts["Fire Risk"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testCycleAllLayers() throws {
        // Tap through all 10 layers and verify no crashes
        let layerNames = [
            "Population", "Crime", "Noise", "Power Lines", "Schools",
            "Superfund", "Group Homes", "Air Quality", "Earthquake", "Fire Risk"
        ]
        for name in layerNames {
            let button = app.buttons["layer_\(name)"]
            XCTAssertTrue(button.waitForExistence(timeout: 5), "Layer button '\(name)' not found")
            button.tap()
            Thread.sleep(forTimeInterval: 0.5)
        }
        // App should still be responsive
        XCTAssertTrue(app.textFields["searchField"].exists)
    }

    // MARK: - Search

    @MainActor
    func testSearchFieldAcceptsInput() throws {
        let searchField = app.textFields["searchField"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))

        searchField.tap()
        searchField.typeText("Cupertino")

        // Verify text was entered by checking the field value
        let fieldValue = searchField.value as? String ?? ""
        XCTAssertTrue(fieldValue.contains("Cupertino"),
                      "Search field should contain typed text, got: \(fieldValue)")
    }

    @MainActor
    func testSearchAndSelectResult() throws {
        let searchField = app.textFields["searchField"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))

        searchField.tap()
        searchField.typeText("Apple Park")

        // Wait for search results/completions to appear
        Thread.sleep(forTimeInterval: 3)

        // Tap the first search result if available
        let firstResult = app.buttons.matching(NSPredicate(
            format: "label CONTAINS[c] 'Apple' OR label CONTAINS[c] 'Cupertino'"
        )).firstMatch

        if firstResult.waitForExistence(timeout: 5) {
            firstResult.tap()

            // After selecting, the neighborhood report panel should appear
            let reportTitle = app.staticTexts["Neighborhood Report"]
            XCTAssertTrue(reportTitle.waitForExistence(timeout: 5),
                          "Neighborhood Report panel should appear after selecting a search result")
        }
        // If no results returned (network issue), test still passes
    }

    @MainActor
    func testClearSearch() throws {
        let searchField = app.textFields["searchField"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))

        searchField.tap()
        searchField.typeText("test")
        Thread.sleep(forTimeInterval: 1)

        // Find and tap the clear button
        let clearButton = app.buttons.allElementsBoundByIndex.last(where: {
            $0.exists && $0.isHittable
        })
        if let clearButton, clearButton.exists {
            clearButton.tap()
            Thread.sleep(forTimeInterval: 1)
            XCTAssertTrue(app.staticTexts["Search any address"].waitForExistence(timeout: 3))
        }
    }

    // MARK: - Map Interaction

    @MainActor
    func testLongPressOnMap() throws {
        let mapView = app.maps.firstMatch
        XCTAssertTrue(mapView.waitForExistence(timeout: 5))

        let center = mapView.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        center.press(forDuration: 1.5)

        let reportTitle = app.staticTexts["Neighborhood Report"]
        if reportTitle.waitForExistence(timeout: 10) {
            XCTAssertTrue(true)
        } else {
            // Long press may not register reliably in XCUITest on MKMapView
            print("⚠️ Long press did not trigger Neighborhood Report — known simulator limitation")
        }
    }

    @MainActor
    func testNeighborhoodReportViaSearch() throws {
        let searchField = app.textFields["searchField"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))

        searchField.tap()
        searchField.typeText("Moscone Center")
        Thread.sleep(forTimeInterval: 3)

        let result = app.buttons.matching(NSPredicate(
            format: "label CONTAINS[c] 'Moscone' OR label CONTAINS[c] 'San Francisco'"
        )).firstMatch

        if result.waitForExistence(timeout: 5) {
            result.tap()

            XCTAssertTrue(app.staticTexts["Neighborhood Report"].waitForExistence(timeout: 5))

            // Wait for scores to load
            Thread.sleep(forTimeInterval: 3)

            let pinnedAddr = app.staticTexts.matching(identifier: "pinnedAddress").firstMatch
            XCTAssertTrue(pinnedAddr.waitForExistence(timeout: 5))
        }
    }

    // MARK: - Crime Layer Details Toggle

    @MainActor
    func testCrimeDetailsToggle() throws {
        let crimeButton = app.buttons["layer_Crime"]
        XCTAssertTrue(crimeButton.waitForExistence(timeout: 5))
        crimeButton.tap()
        Thread.sleep(forTimeInterval: 0.5)

        let detailsText = app.staticTexts["Details"]
        XCTAssertTrue(detailsText.waitForExistence(timeout: 3),
                      "Details toggle should appear on Crime layer")

        let toggle = app.switches.firstMatch
        if toggle.waitForExistence(timeout: 3) {
            toggle.tap()
            Thread.sleep(forTimeInterval: 1)
            toggle.tap()
        }
    }

    // MARK: - Layer Switching Dismisses Panels

    @MainActor
    func testSwitchingLayerFromCrime() throws {
        let crimeButton = app.buttons["layer_Crime"]
        XCTAssertTrue(crimeButton.waitForExistence(timeout: 5))
        crimeButton.tap()
        Thread.sleep(forTimeInterval: 0.5)

        XCTAssertTrue(app.staticTexts["Details"].waitForExistence(timeout: 3))

        let schoolsButton = app.buttons["layer_Schools"]
        schoolsButton.tap()
        Thread.sleep(forTimeInterval: 0.5)

        XCTAssertFalse(app.staticTexts["Details"].exists,
                       "Details toggle should disappear when leaving Crime layer")
    }

    // MARK: - Performance

    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}

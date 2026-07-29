import XCTest

final class MacIslandUITests: XCTestCase {
    @MainActor
    func testShelfTabIsReachableAfterOpeningTheIsland() {
        let app = XCUIApplication()
        app.launch()

        let island = app.windows.firstMatch
        XCTAssertTrue(island.waitForExistence(timeout: 5))

        // y=40 is below the camera-housing safe area in the fixed 210 pt panel.
        island.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 40.0 / 210.0)).tap()

        // The app exposes the tab through its SwiftUI accessibility label.
        let shelf = app.buttons["Shelf"]
        XCTAssertTrue(shelf.waitForExistence(timeout: 5))
        shelf.tap()
        XCTAssertTrue(shelf.isSelected)
    }
}

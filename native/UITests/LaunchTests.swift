import XCTest

final class LaunchTests: XCTestCase {
  @MainActor func testGuestLaunchAndNativeSettingsNavigation() {
    continueAfterFailure = false
    let app = XCUIApplication()
    app.launch()
    let ready = app.tabBars.firstMatch.waitForExistence(timeout: 20)
    capture("Launch state")
    if !ready { let hierarchy = XCTAttachment(string: app.debugDescription); hierarchy.lifetime = .keepAlways; add(hierarchy) }
    XCTAssertTrue(ready)
    XCTAssertEqual(app.tabBars.buttons.count, 4)
    capture("Native home")
    app.tabBars.buttons.element(boundBy: 3).tap()
    let settings = app.buttons["settings.open"]
    XCTAssertTrue(settings.waitForExistence(timeout: 10))
    settings.tap()
    XCTAssertTrue(app.descendants(matching: .any)["settings.form"].firstMatch.waitForExistence(timeout: 10))
    capture("Native settings")
    XCTAssertEqual(app.state, .runningForeground)
  }

  private func capture(_ name: String) {
    let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }
}

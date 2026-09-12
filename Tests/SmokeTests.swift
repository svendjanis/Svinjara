import XCTest
@testable import Svinjara

/// Proves the test target is wired to the app target. Replaced by real coverage as the systems
/// land; kept because a suite that cannot see the app module fails in a confusing way later.
final class SmokeTests: XCTestCase {

    func testAppModelStartsOnTheMenu() {
        XCTAssertEqual(AppModel().screen, .menu)
    }
}

import XCTest
@testable import KelloCore

final class KelloCoreTests: XCTestCase {
    func testNameIsKello() {
        XCTAssertEqual(KelloCore.name, "Kello")
    }
}

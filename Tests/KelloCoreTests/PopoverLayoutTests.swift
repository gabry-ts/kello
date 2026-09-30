import XCTest
@testable import KelloCore

final class PopoverLayoutTests: XCTestCase {
    private func decode(_ json: String) throws -> PopoverLayout {
        try JSONDecoder().decode(PopoverLayout.self, from: Data(json.utf8))
    }

    func testDefaultShowsEverySectionInTodaysOrder() {
        let layout = PopoverLayout()
        XCTAssertEqual(layout.visibleSections, [.grid, .toolbar, .status, .clocks, .nextUp, .list])
        XCTAssertEqual(Set(layout.items.map(\.section)), Set(PopoverSection.allCases))
        XCTAssertTrue(layout.showsNextUpInList)
    }

    func testLockedSections() {
        XCTAssertEqual(PopoverSection.allCases.filter(\.isLocked), [.grid, .toolbar, .list])
    }

    func testMissingItemsDecodeAsDefaults() throws {
        XCTAssertEqual(try decode("{}"), PopoverLayout())
    }

    func testUnreadableItemsDecodeAsDefaults() throws {
        XCTAssertEqual(try decode(#"{"items":[{"section":"weather","isOn":true}]}"#), PopoverLayout())
    }

    func testDecodingKeepsTheSavedOrderAndVisibility() throws {
        let layout = try decode(#"""
        {"items":[{"section":"grid","isOn":true},{"section":"toolbar","isOn":true},{"section":"nextUp","isOn":true},
                  {"section":"status","isOn":false},{"section":"clocks","isOn":true},{"section":"list","isOn":true}]}
        """#)
        XCTAssertEqual(layout.items.map(\.section), [.grid, .toolbar, .nextUp, .status, .clocks, .list])
        XCTAssertFalse(layout.isOn(.status))
        XCTAssertEqual(layout.visibleSections, [.grid, .toolbar, .nextUp, .clocks, .list])
    }

    func testDecodingRepairsMissingAndDuplicateItems() throws {
        let layout = try decode(#"{"items":[{"section":"clocks","isOn":false},{"section":"clocks","isOn":true}]}"#)
        XCTAssertEqual(layout.items.map(\.section), [.grid, .toolbar, .clocks, .status, .nextUp, .list])
        XCTAssertFalse(layout.isOn(.clocks))
        XCTAssertTrue(layout.isOn(.status))
    }

    func testLockedSectionsAreSwitchedOnAndPutBackInPlace() {
        let layout = PopoverLayout(items: [
            PopoverSectionItem(.list, isOn: false),
            PopoverSectionItem(.status),
            PopoverSectionItem(.toolbar, isOn: false),
            PopoverSectionItem(.grid, isOn: false),
            PopoverSectionItem(.nextUp, isOn: false),
            PopoverSectionItem(.clocks),
        ])
        XCTAssertEqual(layout.items.map(\.section), [.grid, .toolbar, .status, .nextUp, .clocks, .list])
        XCTAssertEqual(layout.visibleSections, [.grid, .toolbar, .status, .clocks, .list])
    }

    func testNextUpIsInTheListOnlyRightAboveIt() {
        func layout(_ items: [PopoverSectionItem]) -> PopoverLayout { PopoverLayout(items: items) }
        // Moved above the clocks, it stands on its own.
        XCTAssertFalse(layout([PopoverSectionItem(.status), PopoverSectionItem(.nextUp), PopoverSectionItem(.clocks)]).showsNextUpInList)
        // With the clocks switched off, nothing shown sits between it and the list.
        XCTAssertTrue(layout([PopoverSectionItem(.status), PopoverSectionItem(.nextUp), PopoverSectionItem(.clocks, isOn: false)]).showsNextUpInList)
        // Switched off, it isn't shown at all.
        XCTAssertFalse(layout([PopoverSectionItem(.status), PopoverSectionItem(.clocks), PopoverSectionItem(.nextUp, isOn: false)]).showsNextUpInList)
    }

    func testEncodingRoundTrips() throws {
        var layout = PopoverLayout()
        layout.items = PopoverLayout(items: [PopoverSectionItem(.nextUp), PopoverSectionItem(.status, isOn: false)]).items
        let data = try JSONEncoder().encode(layout)
        XCTAssertEqual(try JSONDecoder().decode(PopoverLayout.self, from: data), layout)
    }
}

import XCTest
@testable import KelloCore

final class WorldClockTests: XCTestCase {
    private let locale = Locale(identifier: "en_US")
    private let rome = TimeZone(identifier: "Europe/Rome")!

    /// Tuesday 29 September 2026, 21:33 in Rome (19:33 UTC).
    private var now: Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = rome
        return calendar.date(from: DateComponents(year: 2026, month: 9, day: 29, hour: 21, minute: 33))!
    }

    func testCityNamesAndLabels() {
        XCTAssertEqual(WorldClock.cityName(for: "America/New_York"), "New York")
        XCTAssertEqual(WorldClock.cityName(for: "America/Argentina/Buenos_Aires"), "Buenos Aires")
        XCTAssertEqual(WorldClockZone(identifier: "Asia/Tokyo").displayName, "Tokyo")
        XCTAssertEqual(WorldClockZone(identifier: "Asia/Tokyo", label: " Office ").displayName, "Office")
    }

    func testReadingsAcrossTheDateLine() {
        let tokyo = WorldClock.reading(for: WorldClockZone(identifier: "Asia/Tokyo"), now: now, here: rome, is24Hour: true, locale: locale)
        XCTAssertEqual(tokyo.time, "04:33")
        XCTAssertEqual(tokyo.dayOffset, 1)
        XCTAssertEqual(tokyo.dayOffsetText, "+1")
        XCTAssertFalse(tokyo.isDaytime)

        let newYork = WorldClock.reading(for: WorldClockZone(identifier: "America/New_York", label: "NYC"), now: now, here: rome,
                                         is24Hour: false, locale: locale)
        XCTAssertEqual(newYork.name, "NYC")
        XCTAssertEqual(newYork.time, "3:33\u{202F}PM")
        XCTAssertNil(newYork.dayOffsetText)
        XCTAssertTrue(newYork.isDaytime)

        // Seen from Tokyo, Honolulu is still on the day before.
        XCTAssertEqual(WorldClock.dayOffset(now, from: TimeZone(identifier: "Asia/Tokyo")!, to: TimeZone(identifier: "Pacific/Honolulu")!), -1)
        XCTAssertEqual(WorldClockReading(name: "", time: "", dayOffset: -1, isDaytime: true).dayOffsetText, "\u{2212}1")
    }

    func testMenuBarText() {
        let text = WorldClock.menuBarText(for: WorldClockZone(identifier: "America/New_York", label: "NYC"), now: now, is24Hour: true, locale: locale)
        XCTAssertEqual(text, "NYC 15:33")
    }

    func testSearch() {
        let identifiers = ["America/New_York", "Europe/Rome", "Asia/Tokyo", "America/Los_Angeles", "Europe/Zurich"]
        XCTAssertEqual(WorldClock.search("new york", in: identifiers, locale: locale), ["America/New_York"])
        XCTAssertEqual(WorldClock.search("europe", in: identifiers, locale: locale), ["Europe/Rome", "Europe/Zurich"])
        XCTAssertEqual(WorldClock.search("pacific", in: identifiers, locale: locale), ["America/Los_Angeles"])
        XCTAssertEqual(WorldClock.search("", in: identifiers, locale: locale).first, "America/Los_Angeles")
    }
}

import XCTest
@testable import KelloCore

final class MenuBarFormatTests: XCTestCase {
    private let locale = Locale(identifier: "en_US")
    private let timeZone = TimeZone(identifier: "UTC")!

    /// Monday, September 28, 2026, 14:05 UTC.
    private var fixedDate: Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar.date(from: DateComponents(year: 2026, month: 9, day: 28, hour: 14, minute: 5))!
    }

    private func text(_ settings: MenuBarSettings) -> String {
        MenuBarFormat.string(for: fixedDate, settings: settings, locale: locale, timeZone: timeZone)
    }

    private func settings(_ items: [(MenuBarComponent, Bool)]) -> MenuBarSettings {
        var settings = MenuBarSettings()
        settings.items = items.map { MenuBarItem($0.0, isOn: $0.1) }
        return settings
    }

    func testDefaultShowsWeekdayDayAndMonth() {
        XCTAssertEqual(text(MenuBarSettings()), "Mon 28 Sep")
    }

    func testEveryComponentOffFallsBackToAppName() {
        XCTAssertEqual(text(settings([(.weekday, false), (.date, false), (.year, false), (.time, false)])), MenuBarFormat.fallback)
    }

    func testComponentsFollowTheirOrder() {
        var timeFirst = settings([(.time, true), (.weekday, true), (.date, true), (.year, false)])
        timeFirst.is24Hour = true
        XCTAssertEqual(text(timeFirst), "14:05 Mon 28 Sep")
    }

    func testCustomPatternIsUsedLiterally() {
        var settings = MenuBarSettings()
        settings.customPattern = "HH:mm · EEE d/M"
        XCTAssertEqual(text(settings), "14:05 · Mon 28/9")
    }

    func testTwelveAndTwentyFourHourClock() {
        var settings = settings([(.time, true), (.weekday, false), (.date, false), (.year, false)])
        XCTAssertEqual(text(settings), "2:05 PM")
        settings.is24Hour = true
        XCTAssertEqual(text(settings), "14:05")
    }

    func testNumericMonthFollowsLocaleOrder() {
        var settings = settings([(.date, true), (.weekday, false), (.year, false), (.time, false)])
        settings.showMonthName = false
        XCTAssertEqual(text(settings), "09/28")
        XCTAssertEqual(MenuBarFormat.string(for: fixedDate, settings: settings, locale: Locale(identifier: "it_IT"), timeZone: timeZone), "28/09")
    }

    func testYearIsShownWhenOn() {
        XCTAssertEqual(text(settings([(.date, true), (.year, true), (.weekday, false), (.time, false)])), "28 Sep 2026")
    }

    func testDecodingRepairsMissingAndDuplicateItems() throws {
        let json = #"{"items":[{"component":"time","isOn":true},{"component":"time","isOn":false}]}"#
        let settings = try JSONDecoder().decode(MenuBarSettings.self, from: Data(json.utf8))
        XCTAssertEqual(settings.items.map(\.component), [.time, .weekday, .date, .year])
        XCTAssertTrue(settings.isOn(.time))
        XCTAssertFalse(settings.isOn(.weekday))
    }
}

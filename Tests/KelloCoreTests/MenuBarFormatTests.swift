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

    func testEveryToggleOffFallsBackToAppName() {
        let settings = MenuBarSettings(showWeekday: false, showDate: false, showYear: false, showTime: false)
        XCTAssertEqual(MenuBarFormat.string(for: fixedDate, settings: settings, locale: locale, timeZone: timeZone), MenuBarFormat.fallback)
    }

    func testCustomPatternOverridesToggles() {
        var settings = MenuBarSettings()
        settings.customPattern = "yyyy-MM-dd HH:mm"
        XCTAssertEqual(MenuBarFormat.string(for: fixedDate, settings: settings, locale: locale, timeZone: timeZone), "2026-09-28 14:05")
    }

    func test24HourClockOmitsAMPM() {
        let settings = MenuBarSettings(showWeekday: false, showDate: false, showYear: false, showTime: true, is24Hour: true)
        let text = MenuBarFormat.string(for: fixedDate, settings: settings, locale: locale, timeZone: timeZone)
        XCTAssertTrue(text.contains("14:05"), text)
        XCTAssertFalse(text.contains("PM"), text)
    }

    func test12HourClockShowsAMPM() {
        let settings = MenuBarSettings(showWeekday: false, showDate: false, showYear: false, showTime: true, is24Hour: false)
        let text = MenuBarFormat.string(for: fixedDate, settings: settings, locale: locale, timeZone: timeZone)
        XCTAssertTrue(text.contains("2:05"), text)
        XCTAssertTrue(text.contains("PM"), text)
    }

    func testMonthAsNameVsNumber() {
        let named = MenuBarSettings(showWeekday: false, showDate: true, showMonthName: true, showYear: false, showTime: false)
        XCTAssertTrue(MenuBarFormat.string(for: fixedDate, settings: named, locale: locale, timeZone: timeZone).contains("Sep"))

        let numeric = MenuBarSettings(showWeekday: false, showDate: true, showMonthName: false, showYear: false, showTime: false)
        XCTAssertTrue(MenuBarFormat.string(for: fixedDate, settings: numeric, locale: locale, timeZone: timeZone).contains("09"))
    }

    func testShowYearIncludesYear() {
        let settings = MenuBarSettings(showWeekday: false, showDate: true, showYear: true, showTime: false)
        XCTAssertTrue(MenuBarFormat.string(for: fixedDate, settings: settings, locale: locale, timeZone: timeZone).contains("2026"))
    }

    func testWeekdayAbbreviation() {
        let settings = MenuBarSettings(showWeekday: true, showDate: false, showYear: false, showTime: false)
        XCTAssertTrue(MenuBarFormat.string(for: fixedDate, settings: settings, locale: locale, timeZone: timeZone).contains("Mon"))
    }
}

import Foundation

/// What the menu bar title shows. Every toggle is ignored once `customPattern` is set.
public struct MenuBarSettings: Codable, Hashable, Sendable {
    public var showWeekday = true
    public var showDate = true
    /// Month spelled out ("Sep") when true, numeric ("09") otherwise.
    public var showMonthName = true
    public var showYear = false
    public var showTime = true
    /// 24-hour clock when true, 12-hour with AM/PM otherwise.
    public var is24Hour = false
    /// A `DateFormatter` template, e.g. "EEE d MMM HH:mm". Overrides every toggle above
    /// when non-empty.
    public var customPattern = ""

    public init(
        showWeekday: Bool = true,
        showDate: Bool = true,
        showMonthName: Bool = true,
        showYear: Bool = false,
        showTime: Bool = true,
        is24Hour: Bool = false,
        customPattern: String = ""
    ) {
        self.showWeekday = showWeekday
        self.showDate = showDate
        self.showMonthName = showMonthName
        self.showYear = showYear
        self.showTime = showTime
        self.is24Hour = is24Hour
        self.customPattern = customPattern
    }
}

/// Builds the menu bar title from `MenuBarSettings`, locale-aware so field order and
/// symbols follow the user's region.
public enum MenuBarFormat {
    /// Shown when every toggle is off and no custom pattern is set, so the item never goes
    /// blank.
    public static let fallback = "Kello"

    public static func string(for date: Date, settings: MenuBarSettings, locale: Locale = .current, timeZone: TimeZone = .current) -> String {
        let pattern = settings.customPattern.trimmingCharacters(in: .whitespacesAndNewlines)
        if !pattern.isEmpty {
            let formatter = DateFormatter()
            formatter.locale = locale
            formatter.timeZone = timeZone
            formatter.dateFormat = pattern
            return formatter.string(from: date)
        }

        // Date.FormatStyle falls back to a full date and time when no component is
        // selected, so every toggle off is handled explicitly instead.
        guard settings.showWeekday || settings.showDate || settings.showYear || settings.showTime else {
            return fallback
        }

        // The hour symbol's own am/pm setting only controls whether "AM"/"PM" is drawn, not
        // the 12- vs 24-hour cycle, so the cycle is forced through the locale instead.
        var localeComponents = Locale.Components(locale: locale)
        if settings.showTime {
            localeComponents.hourCycle = settings.is24Hour ? .zeroToTwentyThree : .oneToTwelve
        }
        let resolvedLocale = Locale(components: localeComponents)

        var style = Date.FormatStyle(locale: resolvedLocale, calendar: Calendar(identifier: .gregorian), timeZone: timeZone)
        if settings.showWeekday {
            style = style.weekday(.abbreviated)
        }
        if settings.showDate {
            style = style.day()
            style = settings.showMonthName ? style.month(.abbreviated) : style.month(.twoDigits)
        }
        if settings.showYear {
            style = style.year()
        }
        if settings.showTime {
            style = style.hour(.defaultDigits(amPM: .abbreviated)).minute(.twoDigits)
        }

        let text = date.formatted(style)
        return text.isEmpty ? fallback : text
    }
}

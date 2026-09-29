import Foundation

/// An event typed as one line, like "Dentist tomorrow at 3pm", ready to become a draft.
public struct QuickEntry: Hashable, Sendable {
    public var title: String
    public var start: Date
    /// For all-day entries, the start of the last day, as `EventDraft` keeps it.
    public var end: Date
    public var isAllDay: Bool

    public init(title: String, start: Date, end: Date, isAllDay: Bool) {
        self.title = title
        self.start = start
        self.end = end
        self.isAllDay = isAllDay
    }

    public func draft(calendarID: String) -> EventDraft {
        EventDraft(calendarID: calendarID, title: title, isAllDay: isAllDay, start: start, end: end)
    }
}

/// Reads a date, a time or a range of either out of a line of English or Italian with
/// `NSDataDetector`, and takes the rest as the title. Without a time the event is all day;
/// without a date it starts at the next full hour, like a new event.
///
/// The detector resolves words like "tomorrow" against the real clock, so only what it
/// matched, the time of day, the day and month and the duration are taken from it; the day
/// itself is worked out against `now`.
public enum QuickEntryParser {
    public static func parse(_ text: String, now: Date, calendar: Calendar = .current) -> QuickEntry? {
        var remaining = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !remaining.isEmpty else { return nil }

        var forcesAllDay = false
        for phrase in allDayPhrases {
            if let range = remaining.range(of: phrase, options: [.caseInsensitive, .diacriticInsensitive]) {
                remaining.removeSubrange(range)
                forcesAllDay = true
            }
        }

        guard let detector, let match = detector.firstMatch(in: remaining, range: NSRange(remaining.startIndex..., in: remaining)),
              let detected = match.date, var range = Range(match.range, in: remaining) else {
            let draft = EventDraft.new(on: now, now: now, calendarID: "", calendar: calendar)
            let title = cleanTitle(remaining)
            if forcesAllDay {
                let day = calendar.startOfDay(for: now)
                return QuickEntry(title: title, start: day, end: day, isAllDay: true)
            }
            return QuickEntry(title: title, start: draft.start, end: draft.end, isAllDay: false)
        }

        let matched = String(remaining[range])
        // The detector reads meals as times of day ("Lunch today 12:30"); the word stays
        // in the title.
        if let first = matched.split(separator: " ").first, mealWords.contains(fold(first)) {
            range = remaining.index(range.lowerBound, offsetBy: first.count)..<range.upperBound
        }
        let title = cleanTitle(remaining.replacingCharacters(in: range, with: " "))

        // The detector works in the system's time zone; its wall-clock fields carry over.
        var system = Calendar(identifier: .gregorian)
        system.timeZone = .current
        let fields = system.dateComponents([.year, .month, .day, .hour, .minute], from: detected)
        guard let day = day(for: matched, fields: fields, now: now, calendar: calendar) else { return nil }

        let hasTime = !forcesAllDay && (fields.hour != 12 || fields.minute != 0 || matches(timePattern, in: matched))
        if hasTime {
            guard let start = calendar.date(bySettingHour: fields.hour ?? 0, minute: fields.minute ?? 0, second: 0, of: day) else { return nil }
            let duration = match.duration > 0 ? match.duration : 3600
            // A time already past on a day given by no word or date means the next one.
            let isTimeOnly = relativeDays(in: matched) == nil && weekday(in: matched) == nil && !hasExplicitDate(matched)
            let adjusted = isTimeOnly && start < now ? (calendar.date(byAdding: .day, value: 1, to: start) ?? start) : start
            return QuickEntry(title: title, start: adjusted, end: adjusted.addingTimeInterval(duration), isAllDay: false)
        }
        let days = max(0, Int((match.duration / 86400).rounded()))
        let last = calendar.date(byAdding: .day, value: days, to: day) ?? day
        return QuickEntry(title: title, start: day, end: last, isAllDay: true)
    }

    // MARK: Days

    /// The start of the day the matched text names, against `now`.
    private static func day(for matched: String, fields: DateComponents, now: Date, calendar: Calendar) -> Date? {
        let today = calendar.startOfDay(for: now)
        if let offset = relativeDays(in: matched) {
            return calendar.date(byAdding: .day, value: offset, to: today)
        }
        if let weekday = weekday(in: matched) {
            let ahead = (weekday - calendar.component(.weekday, from: today) + 7) % 7
            return calendar.date(byAdding: .day, value: ahead, to: today)
        }
        if hasExplicitDate(matched), let month = fields.month, let dayOfMonth = fields.day {
            if matches(yearPattern, in: matched), let year = fields.year {
                return calendar.date(from: DateComponents(year: year, month: month, day: dayOfMonth))
            }
            // No year: the next time that date comes around, today included.
            let year = calendar.component(.year, from: today)
            guard let thisYear = calendar.date(from: DateComponents(year: year, month: month, day: dayOfMonth)) else { return nil }
            return thisYear >= today ? thisYear : calendar.date(byAdding: .year, value: 1, to: thisYear)
        }
        return today
    }

    /// Checked longest first, so "day after tomorrow" isn't read as "tomorrow".
    private static let relativeWords: [(String, Int)] = [
        ("day after tomorrow", 2), ("dopodomani", 2),
        ("tomorrow", 1), ("domani", 1),
        ("today", 0), ("tonight", 0), ("oggi", 0), ("stasera", 0), ("stanotte", 0),
    ]

    private static func relativeDays(in text: String) -> Int? {
        let folded = fold(text)
        return relativeWords.first { folded.contains($0.0) }?.1
    }

    /// Gregorian weekday numbers (1 is Sunday) by English and Italian name.
    private static let weekdays: [String: Int] = {
        var names: [String: Int] = [:]
        for identifier in ["en_US", "it_IT"] {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: identifier)
            for (index, name) in (formatter.weekdaySymbols ?? []).enumerated() { names[fold(name)] = index + 1 }
        }
        for (index, names3) in [["sun"], ["mon"], ["tue", "tues"], ["wed"], ["thu", "thur", "thurs"], ["fri"], ["sat"]].enumerated() {
            for name in names3 { names[name] = index + 1 }
        }
        return names
    }()

    private static func weekday(in text: String) -> Int? {
        words(text).lazy.compactMap { weekdays[$0] }.first
    }

    /// English and Italian month names, full and short.
    private static let monthNames: Set<String> = {
        var names: Set<String> = ["sept"]
        for identifier in ["en_US", "it_IT"] {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: identifier)
            for name in (formatter.monthSymbols ?? []) + (formatter.shortMonthSymbols ?? []) {
                names.insert(fold(name).trimmingCharacters(in: .punctuationCharacters))
            }
        }
        return names
    }()

    /// A month name, or a numeric date like 5/11, 2026-10-14 or 14.10.2026.
    private static func hasExplicitDate(_ text: String) -> Bool {
        words(text).contains { monthNames.contains($0) } || matches(numericDatePattern, in: text)
    }

    // MARK: Text

    nonisolated(unsafe) private static let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue)

    private static let allDayPhrases = ["all-day", "all day", "tutto il giorno", "tutta la giornata"]
    private static let mealWords: Set<String> = ["breakfast", "brunch", "lunch", "dinner", "colazione", "pranzo", "cena"]
    /// Words left dangling at either end once the date is taken out: "Party on", "Cena alle".
    private static let connectors: Set<String> = [
        "on", "at", "from", "for", "by", "the", "in", "@", "-", "–", ",",
        "il", "lo", "la", "le", "alle", "alla", "al", "a", "dalle", "dal", "dalla", "per", "ore", "di",
    ]

    /// Something that can only be a time of day: "15:00", "3pm", "at 12", "alle 12", noon.
    private static let timePattern = #"\d{1,2}[:.]\d{2}|\d\s*(am|pm|a\.m\.|p\.m\.)|\b(at|alle|ore|h)\s*\d|noon|midday|midnight|mezzogiorno|mezzanotte"#
    private static let yearPattern = #"\b(19|20)\d{2}\b"#
    private static let numericDatePattern = #"\b\d{1,2}/\d{1,2}(/\d{2,4})?\b|\b\d{4}-\d{1,2}-\d{1,2}\b|\b\d{1,2}\.\d{1,2}\.\d{2,4}\b"#

    private static func matches(_ pattern: String, in text: String) -> Bool {
        text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
    }

    private static func fold<S: StringProtocol>(_ text: S) -> String {
        String(text).folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
    }

    private static func words(_ text: String) -> [String] {
        fold(text).split { !$0.isLetter }.map(String.init)
    }

    /// The leftover text with spaces collapsed and dangling connectors trimmed.
    private static func cleanTitle(_ text: String) -> String {
        var words = text.split(whereSeparator: \.isWhitespace).map(String.init)
        while let last = words.last, connectors.contains(fold(last)) { words.removeLast() }
        while let first = words.first, connectors.contains(fold(first)) { words.removeFirst() }
        if let last = words.last, last.hasSuffix(",") { words[words.count - 1] = String(last.dropLast()) }
        return words.joined(separator: " ")
    }
}
